use clap::{Parser, Subcommand};
use uuid::Uuid;

#[derive(Parser)]
#[command(name = "gos", author, version, about = "GraphOS Command Line Interface", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,
    
    /// Specify a session ID to resume
    #[arg(short, long)]
    pub session: Option<Uuid>,
    
    /// API host
    #[arg(long, default_value = "localhost")]
    pub api_host: String,
    
    /// API port
    #[arg(long, default_value_t = 4000)]
    pub api_port: u16,
    
    /// Use HTTPS for API connection
    #[arg(long)]
    pub use_https: bool,
    
    /// API provider (openai, anthropic, gemini, custom)
    #[arg(long)]
    pub provider: Option<String>,
    
    /// Model to use (e.g., gpt-4, claude-3-opus, gemini-pro)
    #[arg(long)]
    pub model: Option<String>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// List all available sessions
    List,
    
    /// Show details for a specific session
    Show {
        /// The session ID to show
        id: Uuid,
    },
    
    /// Configure authentication and API settings
    Config {
        #[command(subcommand)]
        action: ConfigCommands,
    },
}

#[derive(Subcommand)]
pub enum ConfigCommands {
    /// Initialize a new configuration file
    Init {
        /// Format for the config file (json, yaml, toml)
        #[arg(short, long, default_value = "toml")]
        format: String,
    },
    
    /// Set RPC authentication secret
    SetSecret {
        /// The secret to use for authentication
        secret: String,
        
        /// Format for the config file (json, yaml, toml)
        #[arg(short, long, default_value = "toml")]
        format: String,
    },
    
    /// Add or update an endpoint configuration
    SetEndpoint {
        /// Name of the endpoint
        name: String,
        
        /// URL of the endpoint
        #[arg(short, long)]
        url: String,
        
        /// Secret for the endpoint
        #[arg(short, long)]
        secret: Option<String>,
        
        /// Use TLS for the connection
        #[arg(long)]
        use_tls: bool,
        
        /// Format for the config file (json, yaml, toml)
        #[arg(short, long, default_value = "toml")]
        format: String,
    },
    
    /// Show the current configuration
    Show,
}