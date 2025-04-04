use std::{collections::HashMap, path::PathBuf, sync::Arc, time::Duration};
use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use tokio::{
    fs,
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpListener, TcpStream},
    select,
    sync::{mpsc, Mutex},
    time::{sleep, timeout},
};
use uuid::Uuid;

const VIBE_PORT: u16 = 9876;

static SESSION_MANAGER: OnceCell<Arc<SessionManager>> = OnceCell::new();

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Session {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub last_active: DateTime<Utc>,
    pub messages: Vec<ChatMessage>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum ChatMessage {
    User(String),
    Assistant(String),
}

#[derive(Debug, Serialize, Deserialize)]
enum SessionCommand {
    GetOrCreateSession,
    GetSession(Uuid),
    UpdateSession(Session),
    ListSessions,
}

#[derive(Debug, Serialize, Deserialize)]
enum SessionResponse {
    Session(Session),
    Sessions(Vec<Session>),
    Error(String),
}

#[derive(Debug)]
pub struct SessionManager {
    sessions_dir: PathBuf,
    is_listener: bool,
    sessions: Arc<Mutex<HashMap<Uuid, Session>>>,
}

impl SessionManager {
    pub async fn init() -> Result<Arc<SessionManager>> {
        if let Some(manager) = SESSION_MANAGER.get() {
            return Ok(manager.clone());
        }

        // Ensure ~/.vibe directory exists
        let home_dir = dirs::home_dir().context("Could not determine home directory")?;
        let sessions_dir = home_dir.join(".vibe");
        fs::create_dir_all(&sessions_dir).await?;

        // Try connecting to existing listener
        println!("Trying to connect to existing listener on port {}", VIBE_PORT);
        let is_listener = match TcpStream::connect(format!("127.0.0.1:{}", VIBE_PORT)).await {
            Ok(stream) => {
                // Listener exists, we're a client
                println!("Connected to existing listener, we're a client");
                drop(stream);
                false
            }
            Err(e) => {
                // No listener, we'll become the listener
                println!("Could not connect to listener: {}, becoming the listener", e);
                true
            }
        };

        let sessions = Arc::new(Mutex::new(HashMap::new()));

        let manager = Arc::new(SessionManager {
            sessions_dir,
            is_listener,
            sessions,
        });

        if is_listener {
            // Load existing sessions from disk
            let manager_clone = manager.clone();
            tokio::spawn(async move {
                if let Err(e) = manager_clone.load_sessions().await {
                    eprintln!("Failed to load sessions: {}", e);
                }
                
                // Start listener service
                if let Err(e) = manager_clone.run_listener().await {
                    eprintln!("Listener service failed: {}", e);
                }
            });
        }

        SESSION_MANAGER.set(manager.clone()).unwrap();
        Ok(manager)
    }

    async fn load_sessions(&self) -> Result<()> {
        let mut entries = fs::read_dir(&self.sessions_dir).await?;
        let mut sessions = self.sessions.lock().await;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().unwrap_or_default() == "json" {
                let mut file = fs::File::open(&path).await?;
                let mut contents = String::new();
                file.read_to_string(&mut contents).await?;
                
                match serde_json::from_str::<Session>(&contents) {
                    Ok(session) => {
                        sessions.insert(session.id, session);
                    }
                    Err(e) => {
                        eprintln!("Failed to parse session file {:?}: {}", path, e);
                    }
                }
            }
        }

        Ok(())
    }

    async fn save_session(&self, session: &Session) -> Result<()> {
        let file_path = self.sessions_dir.join(format!("{}.json", session.id));
        let json = serde_json::to_string_pretty(session)?;
        
        let mut file = fs::File::create(file_path).await?;
        file.write_all(json.as_bytes()).await?;
        
        Ok(())
    }

    async fn run_listener(&self) -> Result<()> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", VIBE_PORT)).await?;
        println!("Session listener started on port {}", VIBE_PORT);

        let (shutdown_tx, mut shutdown_rx) = mpsc::channel::<()>(1);
        let sessions_clone = self.sessions.clone();
        let sessions_dir_clone = self.sessions_dir.clone();

        // Autosave task
        let autosave_shutdown = shutdown_tx.clone();
        tokio::spawn(async move {
            loop {
                select! {
                    _ = sleep(Duration::from_secs(30)) => {
                        let sessions = sessions_clone.lock().await;
                        for session in sessions.values() {
                            let file_path = sessions_dir_clone.join(format!("{}.json", session.id));
                            let json = serde_json::to_string_pretty(session).unwrap_or_default();
                            
                            if let Err(e) = fs::write(&file_path, json).await {
                                eprintln!("Failed to autosave session {}: {}", session.id, e);
                            }
                        }
                    }
                    _ = autosave_shutdown.closed() => {
                        break;
                    }
                }
            }
        });

        loop {
            select! {
                Ok((stream, _)) = listener.accept() => {
                    let sessions_clone = self.sessions.clone();
                    let sessions_dir_clone = self.sessions_dir.clone();
                    tokio::spawn(async move {
                        if let Err(e) = handle_client(stream, sessions_clone, sessions_dir_clone).await {
                            eprintln!("Error handling client: {}", e);
                        }
                    });
                }
                _ = shutdown_rx.recv() => {
                    break;
                }
            }
        }

        Ok(())
    }

    pub async fn get_or_create_session(&self) -> Result<Uuid> {
        if self.is_listener {
            // If we're the listener, create a new session directly
            let session_id = Uuid::new_v4();
            let session = Session {
                id: session_id,
                created_at: Utc::now(),
                last_active: Utc::now(),
                messages: Vec::new(),
            };
            
            let mut sessions = self.sessions.lock().await;
            sessions.insert(session_id, session.clone());
            drop(sessions);
            
            self.save_session(&session).await?;
            
            Ok(session_id)
        } else {
            // If we're a client, send command to the listener
            println!("Sending GetOrCreateSession command to listener");
            let mut stream = match TcpStream::connect(format!("127.0.0.1:{}", VIBE_PORT)).await {
                Ok(stream) => stream,
                Err(e) => {
                    // If we can't connect, we might need to become the listener
                    println!("Failed to connect to listener: {}", e);
                    println!("Creating new session locally");
                    
                    // Create new session locally
                    let session_id = Uuid::new_v4();
                    let session = Session {
                        id: session_id,
                        created_at: Utc::now(),
                        last_active: Utc::now(),
                        messages: Vec::new(),
                    };
                    
                    let mut sessions = self.sessions.lock().await;
                    sessions.insert(session_id, session.clone());
                    drop(sessions);
                    
                    return Ok(session_id);
                }
            };
            
            let command = SessionCommand::GetOrCreateSession;
            let command_json = serde_json::to_string(&command)?;
            
            println!("Writing command to stream");
            stream.write_all(command_json.as_bytes()).await?;
            stream.write_all(b"\n").await?;
            stream.flush().await?;
            
            // Use a timeout for reading to avoid hanging
            let read_future = async {
                let mut buffer = [0u8; 1024];
                let n = stream.read(&mut buffer).await?;
                Ok::<_, anyhow::Error>(String::from_utf8_lossy(&buffer[..n]).to_string())
            };
            
            let response = match timeout(Duration::from_secs(5), read_future).await {
                Ok(Ok(response)) => response,
                Ok(Err(e)) => {
                    println!("Error reading from stream: {}", e);
                    anyhow::bail!("Error reading response: {}", e);
                }
                Err(_) => {
                    println!("Timeout reading from stream");
                    anyhow::bail!("Timeout reading response");
                }
            };
            
            println!("Got response: {}", response);
            
            let session_response: SessionResponse = serde_json::from_str(&response)?;
            
            match session_response {
                SessionResponse::Session(session) => Ok(session.id),
                SessionResponse::Error(err) => anyhow::bail!("Session error: {}", err),
                _ => anyhow::bail!("Unexpected response from session manager"),
            }
        }
    }
    
    pub async fn list_sessions(&self) -> Result<Vec<Session>> {
        if self.is_listener {
            // If we're the listener, get sessions directly
            let sessions = self.sessions.lock().await;
            let session_list = sessions.values().cloned().collect();
            Ok(session_list)
        } else {
            // If we're a client, send command to the listener
            let mut stream = TcpStream::connect(format!("127.0.0.1:{}", VIBE_PORT)).await?;
            
            let command = SessionCommand::ListSessions;
            let command_json = serde_json::to_string(&command)?;
            
            stream.write_all(command_json.as_bytes()).await?;
            stream.write_all(b"\n").await?;
            
            let mut response = String::new();
            stream.read_to_string(&mut response).await?;
            
            let session_response: SessionResponse = serde_json::from_str(&response)?;
            
            match session_response {
                SessionResponse::Sessions(sessions) => Ok(sessions),
                SessionResponse::Error(err) => anyhow::bail!("Session error: {}", err),
                _ => anyhow::bail!("Unexpected response from session manager"),
            }
        }
    }
    
    pub async fn get_session(&self, id: Uuid) -> Result<Option<Session>> {
        if self.is_listener {
            // If we're the listener, get session directly
            let sessions = self.sessions.lock().await;
            Ok(sessions.get(&id).cloned())
        } else {
            // If we're a client, send command to the listener
            let mut stream = TcpStream::connect(format!("127.0.0.1:{}", VIBE_PORT)).await?;
            
            let command = SessionCommand::GetSession(id);
            let command_json = serde_json::to_string(&command)?;
            
            stream.write_all(command_json.as_bytes()).await?;
            stream.write_all(b"\n").await?;
            
            let mut response = String::new();
            stream.read_to_string(&mut response).await?;
            
            let session_response: SessionResponse = serde_json::from_str(&response)?;
            
            match session_response {
                SessionResponse::Session(session) => Ok(Some(session)),
                SessionResponse::Error(_) => Ok(None),
                _ => anyhow::bail!("Unexpected response from session manager"),
            }
        }
    }

    pub async fn update_session(&self, session: Session) -> Result<()> {
        if self.is_listener {
            // If we're the listener, update directly
            let mut sessions = self.sessions.lock().await;
            sessions.insert(session.id, session.clone());
            drop(sessions);
            
            self.save_session(&session).await?;
            
            Ok(())
        } else {
            // If we're a client, send command to the listener
            let mut stream = TcpStream::connect(format!("127.0.0.1:{}", VIBE_PORT)).await?;
            
            let command = SessionCommand::UpdateSession(session);
            let command_json = serde_json::to_string(&command)?;
            
            stream.write_all(command_json.as_bytes()).await?;
            stream.write_all(b"\n").await?;
            
            let mut response = String::new();
            stream.read_to_string(&mut response).await?;
            
            let session_response: SessionResponse = serde_json::from_str(&response)?;
            
            match session_response {
                SessionResponse::Session(_) => Ok(()),
                SessionResponse::Error(err) => anyhow::bail!("Session error: {}", err),
                _ => anyhow::bail!("Unexpected response from session manager"),
            }
        }
    }
}

async fn handle_client(
    mut stream: TcpStream,
    sessions: Arc<Mutex<HashMap<Uuid, Session>>>,
    sessions_dir: PathBuf,
) -> Result<()> {
    println!("Handling client connection");
    
    // Use a timeout for reading to avoid hanging
    let read_future = async {
        let mut buffer = [0u8; 1024];
        let n = stream.read(&mut buffer).await?;
        Ok::<_, anyhow::Error>(String::from_utf8_lossy(&buffer[..n]).to_string())
    };
    
    let buffer = match timeout(Duration::from_secs(5), read_future).await {
        Ok(Ok(buffer)) => buffer,
        Ok(Err(e)) => {
            println!("Error reading from stream: {}", e);
            let error_response = SessionResponse::Error(format!("Error reading command: {}", e));
            let response_json = serde_json::to_string(&error_response)?;
            stream.write_all(response_json.as_bytes()).await?;
            return Ok(());
        }
        Err(_) => {
            println!("Timeout reading from stream");
            let error_response = SessionResponse::Error("Timeout reading command".to_string());
            let response_json = serde_json::to_string(&error_response)?;
            stream.write_all(response_json.as_bytes()).await?;
            return Ok(());
        }
    };
    
    println!("Received command: {}", buffer);
    
    let command: SessionCommand = match serde_json::from_str(&buffer) {
        Ok(cmd) => cmd,
        Err(e) => {
            println!("Failed to parse command: {}", e);
            let error_response = SessionResponse::Error(format!("Invalid command format: {}", e));
            let response_json = serde_json::to_string(&error_response)?;
            stream.write_all(response_json.as_bytes()).await?;
            return Ok(());
        }
    };
    
    println!("Processing command");
    let response = match command {
        SessionCommand::GetOrCreateSession => {
            let session_id = Uuid::new_v4();
            let session = Session {
                id: session_id,
                created_at: Utc::now(),
                last_active: Utc::now(),
                messages: Vec::new(),
            };
            
            let mut sessions_lock = sessions.lock().await;
            sessions_lock.insert(session_id, session.clone());
            
            // Save to disk
            let file_path = sessions_dir.join(format!("{}.json", session_id));
            let json = serde_json::to_string_pretty(&session)?;
            fs::write(file_path, json).await?;
            
            SessionResponse::Session(session)
        },
        SessionCommand::GetSession(id) => {
            let sessions_lock = sessions.lock().await;
            match sessions_lock.get(&id) {
                Some(session) => SessionResponse::Session(session.clone()),
                None => SessionResponse::Error(format!("Session not found: {}", id)),
            }
        },
        SessionCommand::UpdateSession(session) => {
            let mut sessions_lock = sessions.lock().await;
            sessions_lock.insert(session.id, session.clone());
            
            // Save to disk
            let file_path = sessions_dir.join(format!("{}.json", session.id));
            let json = serde_json::to_string_pretty(&session)?;
            fs::write(file_path, json).await?;
            
            SessionResponse::Session(session)
        },
        SessionCommand::ListSessions => {
            let sessions_lock = sessions.lock().await;
            let sessions_list = sessions_lock.values().cloned().collect();
            SessionResponse::Sessions(sessions_list)
        },
    };
    
    let response_json = serde_json::to_string(&response)?;
    stream.write_all(response_json.as_bytes()).await?;
    
    Ok(())
}