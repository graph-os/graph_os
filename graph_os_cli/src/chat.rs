use std::sync::Arc;

use crate::adapters::{JsonRpcClient, Message as ApiMessage, MessageRole};
use crate::session::{ChatMessage as SessionChatMessage, Session, SessionManager};
use crossterm::event::KeyEvent;
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, List, ListItem, Paragraph},
};
use tokio::sync::{mpsc, Mutex};
use uuid::Uuid;

// Commands that can be executed with slash commands
#[derive(Debug, Clone)]
pub enum Command {
    Help,
    Exit,
    ToggleStreaming,
    Config,
    Provider(String),
    Model(String),
    Debug(bool),
    Unknown(String),
}

impl Command {
    pub fn from_input(input: &str) -> Option<Self> {
        if !input.starts_with('/') {
            return None;
        }
        
        let cmd_input = input.trim().to_lowercase();
        
        // Check for commands with arguments
        if cmd_input.starts_with("/provider ") && cmd_input.len() > 10 {
            let provider = cmd_input[10..].trim().to_string();
            return Some(Command::Provider(provider));
        }
        
        if cmd_input.starts_with("/model ") && cmd_input.len() > 7 {
            let model = cmd_input[7..].trim().to_string();
            return Some(Command::Model(model));
        }
        
        if cmd_input == "/debug on" {
            return Some(Command::Debug(true));
        }
        
        if cmd_input == "/debug off" {
            return Some(Command::Debug(false));
        }
        
        // Standard commands without arguments
        match cmd_input.as_str() {
            "/help" => Some(Command::Help),
            "/exit" => Some(Command::Exit),
            "/stream" => Some(Command::ToggleStreaming),
            "/config" => Some(Command::Config),
            _ => Some(Command::Unknown(cmd_input[1..].to_string())),
        }
    }
    
    pub fn help_text() -> String {
        "/help - Show this help message\n\
        /exit - Exit the application\n\
        /stream - Toggle streaming mode\n\
        /config - Show current configuration\n\
        /provider <name> - Switch provider (openai, anthropic, gemini, custom)\n\
        /model <name> - Set model (e.g., gpt-4o, claude-3-opus, gemini-pro)\n\
        /debug on|off - Toggle debug mode".to_string()
    }
}

#[derive(Clone)]
pub enum ChatMessage {
    User(String),
    Assistant(String),
}

impl From<ChatMessage> for SessionChatMessage {
    fn from(msg: ChatMessage) -> Self {
        match msg {
            ChatMessage::User(text) => SessionChatMessage::User(text),
            ChatMessage::Assistant(text) => SessionChatMessage::Assistant(text),
        }
    }
}

impl From<SessionChatMessage> for ChatMessage {
    fn from(msg: SessionChatMessage) -> Self {
        match msg {
            SessionChatMessage::User(text) => ChatMessage::User(text),
            SessionChatMessage::Assistant(text) => ChatMessage::Assistant(text),
        }
    }
}

pub struct ChatApp {
    pub messages: Vec<ChatMessage>,
    pub input: String,
    pub cursor_position: usize,
    pub session_id: Uuid,
    pub session_manager: Arc<SessionManager>,
    pub graph_os_client: Option<JsonRpcClient>,
    pub show_commands: bool,
    pub exit_requested: bool,
    pub connected: bool,
    pub streaming: bool,
    pub current_stream: Arc<Mutex<String>>,
    pub stream_active: bool,
    pub current_provider: Option<crate::config::ApiProvider>,
    pub available_providers: Vec<crate::config::ApiProvider>,
    pub config_manager: Arc<crate::config::ConfigManager>,
    pub debug_mode: bool,
}

impl ChatApp {
    pub async fn new(
        session_id: Uuid, 
        session_manager: Arc<SessionManager>,
        host: Option<String>,
        port: Option<u16>,
        https: bool,
        api_config: Option<crate::config::ApiConfig>,
        model_override: Option<String>,
        rpc_secret: Option<String>,
    ) -> anyhow::Result<Self> {
        // Get the config manager
        let config_manager = Arc::new(crate::config::ConfigManager::instance().clone());
        
        // Load current configuration
        let config = config_manager.load().await?;
        
        // Get available providers
        let available_providers = config.apis.keys().cloned().collect();
        
        // Get current provider from API config
        let current_provider = if let Some(config) = &api_config {
            Some(config.provider)
        } else {
            config.default_provider
        };
        // Try to get existing session from the manager
        let existing_session = session_manager.get_session(session_id).await?;
        
        // Create API client
        let graph_os_client = if let Some(config) = api_config {
            // Use configuration from API provider
            let endpoint = if let Some(api_url) = config.api_url {
                api_url
            } else if let (Some(host), Some(port)) = (host, port) {
                let scheme = if https { "https" } else { "http" };
                format!("{}://{}:{}/api/jsonrpc", scheme, host, port)
            } else {
                // No endpoint specified
                return Err(anyhow::anyhow!("No API endpoint specified"));
            };
            
            // Determine model to use (CLI override takes precedence)
            let model = model_override.or(config.model);
            
            Some(JsonRpcClient::with_endpoint(endpoint, Some(config.api_key), model, rpc_secret))
        } else if let (Some(host), Some(port)) = (host, port) {
            // No API config, just use host/port
            Some(JsonRpcClient::new(&host, port, https, None, model_override, rpc_secret))
        } else {
            None
        };
        
        // Initialize messages based on whether this is a new session or existing one
        let messages = if let Some(session) = existing_session {
            // Convert session messages to chat messages
            session.messages.into_iter().map(ChatMessage::from).collect()
        } else {
            // Create a new session
            let session = Session {
                id: session_id,
                created_at: chrono::Utc::now(),
                last_active: chrono::Utc::now(),
                messages: vec![],
            };
            
            // Store the new session
            session_manager.update_session(session).await?;
            
            // Default welcome message for new sessions
            vec![
                ChatMessage::Assistant("Hello! I'm Vibe, your AI assistant. How can I help you today?".to_string()),
            ]
        };
        
        // Check if we can actually connect to the API endpoint
        let connected = if let Some(client) = &graph_os_client {
            // Try a simple ping request to test connectivity
            match client.ping().await {
                Ok(true) => true,
                _ => false,
            }
        } else {
            false
        };
        
        Ok(Self {
            messages,
            input: String::new(),
            cursor_position: 0,
            session_id,
            session_manager,
            graph_os_client,
            show_commands: true, // Always show commands for testing
            exit_requested: false,
            connected,
            streaming: true, // Enable streaming by default
            current_stream: Arc::new(Mutex::new(String::new())),
            stream_active: false,
            current_provider,
            available_providers,
            config_manager,
            debug_mode: true, // Debug mode ON by default for testing
        })
    }
    
    pub async fn save_session(&self) -> anyhow::Result<()> {
        // Convert our local messages to session messages
        let session_messages: Vec<SessionChatMessage> = 
            self.messages.iter().map(|msg| {
                match msg {
                    ChatMessage::User(text) => SessionChatMessage::User(text.clone()),
                    ChatMessage::Assistant(text) => SessionChatMessage::Assistant(text.clone()),
                }
            }).collect();
            
        let session = Session {
            id: self.session_id,
            created_at: chrono::Utc::now(), // This is just a placeholder, should be preserved
            last_active: chrono::Utc::now(),
            messages: session_messages,
        };
        
        self.session_manager.update_session(session).await?;
        Ok(())
    }

    pub fn push_message(&mut self, message: ChatMessage) {
        self.messages.push(message);
    }

    pub async fn submit_message(&mut self) -> anyhow::Result<()> {
        if !self.input.is_empty() {
            let user_message = std::mem::take(&mut self.input);
            self.push_message(ChatMessage::User(user_message.clone()));
            
            // Convert chat history to API message format
            let api_messages = self.get_conversation_history();
            
            // Response to show to the user
            if self.connected && self.graph_os_client.is_some() {
                // Start a streaming response if enabled
                if self.streaming {
                    // Add an empty assistant message that will be updated as the stream comes in
                    self.push_message(ChatMessage::Assistant(String::new()));
                    
                    // Mark streaming as active
                    self.stream_active = true;
                    
                    // Get what we need for the async task
                    let client = self.graph_os_client.as_ref().unwrap().clone();
                    let session_id = self.session_id;
                    let session_manager = self.session_manager.clone();
                    let current_stream = self.current_stream.clone();
                    let api_messages = api_messages.clone();
                    let user_msg = user_message.clone();
                    
                    // Process stream in a separate task
                    tokio::spawn(async move {
                        let (tx, mut rx) = mpsc::channel::<String>(32);
                        
                        // Start streaming request
                        if let Err(e) = client.chat(api_messages, true, Some(tx)).await {
                            // Update the current stream with error message
                            let mut stream = current_stream.lock().await;
                            *stream = format!("Error: {}. Falling back to echo: {}", e, user_msg);
                            return;
                        }
                        
                        // Process incoming stream chunks
                        let mut full_response = String::new();
                        while let Some(chunk) = rx.recv().await {
                            full_response.push_str(&chunk);
                            
                            // Update the current stream
                            {
                                let mut stream = current_stream.lock().await;
                                *stream = full_response.clone();
                            }
                        }
                        
                        // Stream is complete, update session
                        let mut messages = Vec::new();
                        
                        // Get all session messages including the last user message
                        if let Ok(Some(session)) = session_manager.get_session(session_id).await {
                            // Replace the last assistant message (empty one) with the full response
                            messages = session.messages;
                            if let Some(SessionChatMessage::Assistant(_)) = messages.last() {
                                // Remove the last message
                                messages.pop();
                            }
                        }
                        
                        // Add the completed assistant message
                        messages.push(SessionChatMessage::Assistant(full_response));
                        
                        // Update the session with the new messages
                        let updated_session = Session {
                            id: session_id,
                            created_at: chrono::Utc::now(),
                            last_active: chrono::Utc::now(),
                            messages,
                        };
                        
                        if let Err(e) = session_manager.update_session(updated_session).await {
                            eprintln!("Error updating session after streaming: {}", e);
                        }
                    });
                } else {
                    // Non-streaming request
                    let client = self.graph_os_client.as_ref().unwrap();
                    
                    match client.chat(api_messages, false, None).await {
                        Ok(response) => {
                            self.push_message(ChatMessage::Assistant(response));
                        },
                        Err(e) => {
                            // Fall back to local response on error
                            let fallback = format!("Error: {}. Falling back to echo: {}", e, user_message);
                            self.push_message(ChatMessage::Assistant(fallback));
                        }
                    }
                    
                    // Save the session after each message
                    self.save_session().await?;
                }
            } else if self.graph_os_client.is_some() {
                // Connection configured but not available
                let fallback = format!("Connection unavailable. Echo: {}", user_message);
                self.push_message(ChatMessage::Assistant(fallback));
                self.save_session().await?;
            } else {
                // No client configured, just echo back
                let fallback = format!("No connection configured. Echo: {}", user_message);
                self.push_message(ChatMessage::Assistant(fallback));
                self.save_session().await?;
            }
            
            self.cursor_position = 0;
        }
        Ok(())
    }
    
    /// Convert the chat history to the API message format
    fn get_conversation_history(&self) -> Vec<ApiMessage> {
        let mut api_messages = Vec::new();
        
        // Add system message if desired
        api_messages.push(ApiMessage {
            role: MessageRole::System,
            content: "You are a helpful assistant.".to_string(),
        });
        
        // Add conversation history
        for msg in &self.messages {
            match msg {
                ChatMessage::User(content) => {
                    api_messages.push(ApiMessage {
                        role: MessageRole::User,
                        content: content.clone(),
                    });
                },
                ChatMessage::Assistant(content) => {
                    // Only add non-empty assistant messages to the history
                    if !content.is_empty() {
                        api_messages.push(ApiMessage {
                            role: MessageRole::Assistant,
                            content: content.clone(),
                        });
                    }
                },
            }
        }
        
        api_messages
    }

    /// Get filtered commands based on current input
    fn get_filtered_commands(&self) -> Vec<String> {
        let available_commands = vec![
            "/help",
            "/exit",
            "/stream",
            "/config",
            "/provider",
            "/model",
            "/debug on",
            "/debug off",
        ];
        
        if self.input.starts_with('/') {
            // Filter commands that start with the current input
            available_commands
                .iter()
                .filter(|cmd| cmd.starts_with(&self.input))
                .map(|cmd| cmd.to_string())
                .collect()
        } else {
            Vec::new()
        }
    }
    
    pub fn handle_input(&mut self, key: KeyEvent) -> Option<mpsc::Sender<()>> {
        match key.code {
            crossterm::event::KeyCode::Enter => {
                // Check if the input is a command
                if let Some(command) = Command::from_input(&self.input) {
                    self.handle_command(command);
                    self.input.clear();
                    self.cursor_position = 0;
                    return None;
                }
                
                let tx = mpsc::channel::<()>(1).0;
                return Some(tx); // Return channel for async processing
            }
            crossterm::event::KeyCode::Tab => {
                // Auto-complete command if it's unambiguous
                if self.input.starts_with('/') {
                    let filtered = self.get_filtered_commands();
                    if filtered.len() == 1 {
                        // Add space after command if it's not a command with a toggle
                        let completion = if filtered[0].ends_with(" on") || filtered[0].ends_with(" off") {
                            filtered[0].clone()
                        } else {
                            format!("{} ", filtered[0])
                        };
                        self.input = completion;
                        self.cursor_position = self.input.len();
                    } else if !filtered.is_empty() {
                        // Find the longest common prefix for partial completion
                        let mut common_prefix = filtered[0].clone();
                        for cmd in &filtered[1..] {
                            let mut new_prefix = String::new();
                            for (a, b) in common_prefix.chars().zip(cmd.chars()) {
                                if a == b {
                                    new_prefix.push(a);
                                } else {
                                    break;
                                }
                            }
                            common_prefix = new_prefix;
                        }
                        if common_prefix.len() > self.input.len() {
                            self.input = common_prefix;
                            self.cursor_position = self.input.len();
                        }
                    }
                }
            }
            crossterm::event::KeyCode::Char(c) => {
                self.input.insert(self.cursor_position, c);
                self.cursor_position += 1;
                
                // Always show command suggestions for testing
                self.show_commands = true;
                
                // Log that a character was typed for debugging
                eprintln!("Character typed: {}", c);
            }
            crossterm::event::KeyCode::Backspace => {
                if self.cursor_position > 0 {
                    self.cursor_position -= 1;
                    self.input.remove(self.cursor_position);
                    
                    // Always show commands for testing
                    self.show_commands = true;
                    eprintln!("Backspace pressed");
                }
            }
            crossterm::event::KeyCode::Left => {
                if self.cursor_position > 0 {
                    self.cursor_position -= 1;
                }
            }
            crossterm::event::KeyCode::Right => {
                if self.cursor_position < self.input.len() {
                    self.cursor_position += 1;
                }
            }
            _ => {}
        }
        None
    }
    
    /// Check if provider is available in the configuration
    pub async fn is_provider_available(&self, provider: crate::config::ApiProvider) -> bool {
        // Load config
        if let Ok(config) = self.config_manager.load().await {
            // Check if provider is available
            config.get_api_config(provider).is_some()
        } else {
            false
        }
    }
    
    /// Show current configuration
    pub fn show_config(&mut self) {
        let mut config_info = String::new();
        
        // Show current provider
        if let Some(provider) = self.current_provider {
            config_info.push_str(&format!("🔌 Current provider: {}\n", provider));
        } else {
            config_info.push_str("🔌 No provider selected\n");
        }
        
        // Show connection status
        if self.connected {
            if let Some(client) = &self.graph_os_client {
                config_info.push_str(&format!("🌐 Connected to: {}\n", client.endpoint));
            } else {
                config_info.push_str("🌐 Connection status: Connected\n");
            }
        } else {
            config_info.push_str("🌐 Connection status: Disconnected\n");
        }
        
        // Show model information if available
        if let Some(client) = &self.graph_os_client {
            if let Some(model) = &client.model {
                config_info.push_str(&format!("🧠 Current model: {}\n", model));
            } else {
                config_info.push_str("🧠 Model: Not specified\n");
            }
        }
        
        // Show settings
        config_info.push_str("\n⚙️ Settings:\n");
        
        // Show streaming status
        let streaming_status = if self.streaming { "enabled" } else { "disabled" };
        config_info.push_str(&format!("- Streaming: {}\n", streaming_status));
        
        // Show debug mode
        let debug_status = if self.debug_mode { "enabled" } else { "disabled" };
        config_info.push_str(&format!("- Debug mode: {}\n", debug_status));
        
        // Show available providers
        if !self.available_providers.is_empty() {
            config_info.push_str("\n🔌 Available providers:\n");
            for provider in &self.available_providers {
                let marker = if Some(*provider) == self.current_provider { "→ " } else { "  " };
                config_info.push_str(&format!("{}{}\n", marker, provider));
            }
        } else {
            config_info.push_str("\n🔌 No API providers configured in ~/.vibe/.env\n");
        }
        
        // Add tips
        config_info.push_str("\n💡 Tips:\n");
        config_info.push_str("- Use /provider <name> to switch providers\n");
        config_info.push_str("- Use /model <name> to change models\n");
        config_info.push_str("- Use /stream to toggle streaming mode\n");
        
        self.push_message(ChatMessage::Assistant(config_info));
    }

    pub fn handle_command(&mut self, command: Command) {
        match command {
            Command::Help => {
                self.push_message(ChatMessage::Assistant(Command::help_text()));
            }
            Command::Exit => {
                self.exit_requested = true;
            }
            Command::ToggleStreaming => {
                self.streaming = !self.streaming;
                let status = if self.streaming { "enabled" } else { "disabled" };
                self.push_message(ChatMessage::Assistant(format!("Streaming mode {}.", status)));
            }
            Command::Config => {
                self.show_config();
            }
            Command::Provider(provider) => {
                // Add a temporary message to indicate request received
                self.push_message(ChatMessage::Assistant(format!("Provider switch to {} requested. Use /config to check configuration.", provider)));
                
                // Convert provider name to enum
                let provider_enum = match provider.to_lowercase().as_str() {
                    "openai" => Some(crate::config::ApiProvider::OpenAI),
                    "anthropic" => Some(crate::config::ApiProvider::Anthropic),
                    "gemini" => Some(crate::config::ApiProvider::Gemini),
                    "custom" => Some(crate::config::ApiProvider::Custom),
                    _ => None,
                };
                
                // We can only set the desired provider, not do the actual switch here
                // since we can't run async code in this method
                if let Some(p) = provider_enum {
                    self.current_provider = Some(p);
                } else {
                    self.push_message(ChatMessage::Assistant(
                        format!("Unknown provider: '{}'. Available options: openai, anthropic, gemini, custom", provider)
                    ));
                }
            }
            Command::Model(model) => {
                // Update the model in the current client
                if let Some(client) = &mut self.graph_os_client {
                    client.model = Some(model.clone());
                    self.push_message(ChatMessage::Assistant(format!("Model set to: {}", model)));
                } else {
                    self.push_message(ChatMessage::Assistant(
                        "No active API client. Please connect to a provider first.".to_string()
                    ));
                }
            }
            Command::Debug(enabled) => {
                self.debug_mode = enabled;
                let status = if enabled { "enabled" } else { "disabled" };
                self.push_message(ChatMessage::Assistant(format!("Debug mode {}.", status)));
                
                // Show additional debug information if enabled
                if enabled {
                    let mut debug_info = String::new();
                    
                    // Show API client details
                    if let Some(client) = &self.graph_os_client {
                        debug_info.push_str("API client details:\n");
                        debug_info.push_str(&format!("- Endpoint: {}\n", client.endpoint));
                        debug_info.push_str(&format!("- Has API key: {}\n", client.api_key.is_some()));
                        debug_info.push_str(&format!("- Model: {:?}\n", client.model));
                    } else {
                        debug_info.push_str("No API client configured\n");
                    }
                    
                    // Show session details
                    debug_info.push_str(&format!("Session ID: {}\n", self.session_id));
                    debug_info.push_str(&format!("Message count: {}\n", self.messages.len()));
                    
                    self.push_message(ChatMessage::Assistant(debug_info));
                }
            }
            Command::Unknown(cmd) => {
                self.push_message(ChatMessage::Assistant(format!("Unknown command: '{}'. Type /help to see available commands.", cmd)));
            }
        }
    }
}

pub fn ui(frame: &mut Frame, app: &ChatApp) {
    // Adjust layout constraints based on whether we're showing commands
    let constraints = if app.show_commands {
        vec![
            Constraint::Min(0),
            Constraint::Length(5),  // Command suggestions area
            Constraint::Length(3),
            Constraint::Length(1)
        ]
    } else {
        vec![
            Constraint::Min(0),
            Constraint::Length(3),
            Constraint::Length(1)
        ]
    };
    
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(constraints)
        .split(frame.area());

    // Messages area
    let mut messages = Vec::new();
    for (i, msg) in app.messages.iter().enumerate() {
        match msg {
            ChatMessage::User(text) => {
                messages.push(ListItem::new(format!("You: {}", text)).style(Style::default().fg(Color::Blue)));
            }
            ChatMessage::Assistant(text) => {
                // If this is the last message and streaming is active, add a typing indicator
                if i == app.messages.len() - 1 && app.stream_active {
                    let display_text = if text.is_empty() { 
                        "...".to_string() 
                    } else {
                        format!("{}", text)
                    };
                    messages.push(ListItem::new(format!("Assistant: {}", display_text))
                        .style(Style::default().fg(Color::Green)));
                } else {
                    messages.push(ListItem::new(format!("Assistant: {}", text))
                        .style(Style::default().fg(Color::Green)));
                }
            }
        }
    }

    let messages_list = List::new(messages)
        .block(Block::default().borders(Borders::ALL).title("Chat"))
        .style(Style::default().fg(Color::White))
        .highlight_style(Style::default().add_modifier(Modifier::ITALIC))
        .highlight_symbol(">>");

    frame.render_widget(messages_list, chunks[0]);

    // Command suggestions area (shown only when app.show_commands is true)
    if app.show_commands {
        // Command descriptions for display
        let commands_with_descriptions = vec![
            ("/help", "Show this help message"),
            ("/exit", "Exit the application"),
            ("/stream", "Toggle streaming mode"),
            ("/config", "Show current configuration"),
            ("/provider", "Switch provider (openai, anthropic, gemini, custom)"),
            ("/model", "Set model (e.g., gpt-4o, claude-3-opus, gemini-pro)"),
            ("/debug on", "Enable debug mode"),
            ("/debug off", "Disable debug mode"),
        ];
        
        // Filter commands based on what the user is typing
        let filtered_commands = app.get_filtered_commands();
        
        // Map to descriptions
        let filtered_with_descriptions: Vec<String> = if !filtered_commands.is_empty() {
            filtered_commands.iter()
                .map(|cmd| {
                    let cmd_base = cmd.split_whitespace().next().unwrap_or(cmd);
                    let description = commands_with_descriptions.iter()
                        .find(|(c, _)| *c == cmd_base)
                        .map(|(_, desc)| *desc)
                        .unwrap_or("");
                    format!("{} - {}", cmd, description)
                })
                .collect()
        } else if !app.input.starts_with('/') {
            // Show all if not typing a command
            commands_with_descriptions.iter()
                .map(|(cmd, desc)| format!("{} - {}", cmd, desc))
                .collect()
        } else {
            Vec::new()
        };
            
        // Create the command text
        let command_text = if filtered_with_descriptions.is_empty() {
            "No matching commands found".to_string()
        } else {
            filtered_with_descriptions.join("\n")
        };
        
        let commands = Paragraph::new(command_text)
            .block(Block::default().borders(Borders::ALL).title("Commands"))
            .style(Style::default().fg(Color::Cyan));
        
        frame.render_widget(commands, chunks[1]);
    }
    
    // Input area
    let input_block = Block::default()
        .borders(Borders::ALL)
        .title("Input");
    
    let input = Paragraph::new(app.input.as_str())
        .style(Style::default().fg(Color::Yellow))
        .block(input_block);
    
    frame.render_widget(input, chunks[if app.show_commands { 2 } else { 1 }]);
    
    // Status line - show connection status
    let status_chunk = if app.show_commands { chunks[3] } else { chunks[2] };
    let status_text = if app.connected {
        // Build endpoint string from client information
        let endpoint = if let Some(client) = &app.graph_os_client {
            client.endpoint.clone()
        } else {
            "unknown endpoint".to_string()
        };
        format!("Connected to {} | Press Ctrl+Q to quit", endpoint)
    } else if app.graph_os_client.is_some() {
        "Not connected (service unavailable) | Press Ctrl+Q to quit".to_string()
    } else {
        "Local mode (no connection) | Press Ctrl+Q to quit".to_string()
    };
    
    let status = Paragraph::new(status_text)
        .style(Style::default().fg(
            if app.connected { Color::LightGreen } 
            else if app.graph_os_client.is_some() { Color::Yellow }
            else { Color::LightRed }
        ));
    
    frame.render_widget(status, status_chunk);
    
    // Show cursor at the current input position
    let input_chunk_idx = if app.show_commands { 2 } else { 1 };
    let cursor_position = Position::new(
        chunks[input_chunk_idx].x + app.cursor_position as u16 + 1,
        chunks[input_chunk_idx].y + 1
    );
    frame.set_cursor_position(cursor_position);
}

pub fn setup_terminal() -> anyhow::Result<Terminal<CrosstermBackend<std::io::Stdout>>> {
    let mut stdout = std::io::stdout();
    crossterm::terminal::enable_raw_mode()?;
    crossterm::execute!(
        stdout,
        crossterm::terminal::EnterAlternateScreen,
        crossterm::event::EnableMouseCapture
    )?;
    
    let backend = CrosstermBackend::new(stdout);
    let terminal = Terminal::new(backend)?;
    Ok(terminal)
}

pub fn restore_terminal() -> anyhow::Result<()> {
    crossterm::terminal::disable_raw_mode()?;
    crossterm::execute!(
        std::io::stdout(),
        crossterm::terminal::LeaveAlternateScreen,
        crossterm::event::DisableMouseCapture
    )?;
    Ok(())
}