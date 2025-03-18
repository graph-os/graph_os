mod session;
mod adapters;
mod chat;
mod cli;
mod config;

use std::time::Duration;

use chat::{ChatApp, setup_terminal, restore_terminal, ui};
use clap::Parser;
use cli::{Cli, Commands, ConfigCommands};
use config::{ConfigManager, ConfigFormat, EndpointConfig};
use tokio::sync::mpsc;

use session::SessionManager;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Parse command line args
    let cli = Cli::parse();
    
    // Load API configuration from environment variables
    let config = ConfigManager::instance().load().await?;
    
    // Log available API providers
    if let Some(default) = config.default_provider {
        println!("Default API provider: {}", default);
    } else {
        println!("No API providers configured. Check your environment variables or ~/.env file.");
    }
    
    // Initialize the session manager
    let session_manager = SessionManager::init().await?;
    
    // Handle subcommands
    match &cli.command {
        Some(Commands::List) => {
            let sessions = session_manager.list_sessions().await?;
            println!("Available sessions:");
            for session in sessions {
                println!("{}: created at {}, last active at {}", 
                         session.id, 
                         session.created_at.format("%Y-%m-%d %H:%M:%S"),
                         session.last_active.format("%Y-%m-%d %H:%M:%S"));
            }
            return Ok(());
        }
        Some(Commands::Show { id }) => {
            if let Some(session) = session_manager.get_session(*id).await? {
                println!("Session details for {}:", session.id);
                println!("Created at: {}", session.created_at.format("%Y-%m-%d %H:%M:%S"));
                println!("Last active: {}", session.last_active.format("%Y-%m-%d %H:%M:%S"));
                println!("Message count: {}", session.messages.len());
                return Ok(());
            } else {
                eprintln!("Session not found: {}", id);
                return Ok(());
            }
        }
        Some(Commands::Config { action }) => {
            // Parse config format
            let parse_format = |format_str: &str| -> Result<ConfigFormat, anyhow::Error> {
                match format_str.to_lowercase().as_str() {
                    "json" => Ok(ConfigFormat::Json),
                    "yaml" | "yml" => Ok(ConfigFormat::Yaml),
                    "toml" => Ok(ConfigFormat::Toml),
                    _ => Err(anyhow::anyhow!("Invalid format: {}, supported formats are json, yaml, toml", format_str)),
                }
            };
            
            match action {
                ConfigCommands::Init { format } => {
                    let format = parse_format(format)?;
                    let path = ConfigManager::instance().create_default_auth_config(format).await?;
                    println!("Created new config file at: {}", path.display());
                }
                ConfigCommands::SetSecret { secret, format } => {
                    let format = parse_format(format)?;
                    let path = ConfigManager::instance().set_rpc_secret(secret, format).await?;
                    println!("Updated RPC secret in config file: {}", path.display());
                }
                ConfigCommands::SetEndpoint { name, url, secret, use_tls, format } => {
                    let format = parse_format(format)?;
                    
                    let endpoint = EndpointConfig {
                        url: url.clone(),
                        secret: secret.clone(),
                        token: None,
                        use_tls: Some(*use_tls),
                    };
                    
                    let path = ConfigManager::instance().set_endpoint_config(name, endpoint, format).await?;
                    println!("Updated endpoint '{}' in config file: {}", name, path.display());
                }
                ConfigCommands::Show => {
                    let config = ConfigManager::instance().get_config().await?;
                    
                    println!("Authentication configuration:");
                    
                    if let Some(auth) = &config.auth {
                        println!("  RPC Secret: {}", if auth.rpc_secret.is_some() { "[configured]" } else { "[not set]" });
                        
                        if !auth.endpoints.is_empty() {
                            println!("\nConfigured endpoints:");
                            for (name, endpoint) in &auth.endpoints {
                                println!("  {}: {}{}", 
                                    name, 
                                    if endpoint.use_tls.unwrap_or(false) { "https://" } else { "http://" },
                                    endpoint.url
                                );
                                println!("    Secret: {}", if endpoint.secret.is_some() { "[configured]" } else { "[not set]" });
                            }
                        } else {
                            println!("\nNo endpoints configured");
                        }
                    } else {
                        println!("No authentication configuration found");
                        println!("Run 'gos config init' to create a default configuration file");
                    }
                    
                    println!("\nAPI providers:");
                    if config.apis.is_empty() {
                        println!("  No API providers configured");
                    } else {
                        for provider in config.available_providers() {
                            let is_default = config.default_provider.map_or(false, |p| p == provider);
                            println!("  {}{}: {}", 
                                provider,
                                if is_default { " (default)" } else { "" },
                                if let Some(config) = config.get_api_config(provider) {
                                    if let Some(model) = &config.model {
                                        format!("model = {}", model)
                                    } else {
                                        "default model".to_string()
                                    }
                                } else {
                                    "not configured".to_string()
                                }
                            );
                        }
                    }
                }
            }
            
            return Ok(());
        }
        None => {
            // Normal operation - open chat UI
            let mut terminal = setup_terminal()?;
            
            // Get or create a session
            let session_id = if let Some(id) = cli.session {
                // Verify the session exists
                if session_manager.get_session(id).await?.is_some() {
                    id
                } else {
                    eprintln!("Session not found: {}, creating a new session", id);
                    session_manager.get_or_create_session().await?
                }
            } else {
                session_manager.get_or_create_session().await?
            };
            
            // Configure API connection based on configuration
            let api_config = if let Some(provider_str) = &cli.provider {
                // Determine provider from CLI argument
                let provider = match provider_str.to_lowercase().as_str() {
                    "openai" => Some(config::ApiProvider::OpenAI),
                    "anthropic" => Some(config::ApiProvider::Anthropic),
                    "gemini" => Some(config::ApiProvider::Gemini),
                    "custom" => Some(config::ApiProvider::Custom),
                    _ => None,
                };
                
                // Get config for the specified provider
                provider.and_then(|p| config.get_api_config(p))
            } else {
                // Use default provider
                config.get_default_api_config()
            };
            
            // Get RPC authentication from config
            let rpc_secret = config.get_rpc_secret();
            
            // Create the chat app
            let mut app = ChatApp::new(
                session_id,
                session_manager.clone(),
                Some(cli.api_host),
                Some(cli.api_port),
                cli.use_https,
                api_config,
                cli.model,
                rpc_secret,
            ).await?;
            
            let (tx, mut rx) = mpsc::channel(10);
            
            // Spawn a task to handle key events
            let event_tx = tx.clone();
            tokio::spawn(async move {
                loop {
                    if crossterm::event::poll(Duration::from_millis(100)).unwrap() {
                        if let crossterm::event::Event::Key(key) = crossterm::event::read().unwrap() {
                            event_tx.send(key).await.unwrap();
                            if key.code == crossterm::event::KeyCode::Char('q') && key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL) {
                                break;
                            }
                        }
                    }
                }
            });
            
            loop {
                terminal.draw(|f| ui(f, &app))?;
                
                // Check if exit was requested via the /exit command
                if app.exit_requested {
                    break;
                }
                
                if let Some(key) = rx.recv().await {
                    if key.code == crossterm::event::KeyCode::Char('q') && key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL) {
                        break;
                    }
                    
                    // Handle the input and check if we need to submit a message
                    if let Some(submit_tx) = app.handle_input(key) {
                        let app_ref = &mut app;
                        // Submit the message asynchronously
                        if let Err(e) = app_ref.submit_message().await {
                            eprintln!("Error submitting message: {}", e);
                        }
                        // Signal that we're done with the async operation
                        drop(submit_tx);
                    }
                }
            }
            
            // Save session one last time before exiting
            if let Err(e) = app.save_session().await {
                eprintln!("Error saving session: {}", e);
            }
            
            restore_terminal()?;
        }
    }
    
    Ok(())
}