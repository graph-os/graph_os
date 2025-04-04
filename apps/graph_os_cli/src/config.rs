use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::Mutex;
use serde::{Deserialize, Serialize};
use anyhow::{Result, Context, anyhow};

/// API providers supported by the application
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ApiProvider {
    OpenAI,
    Anthropic,
    Gemini,
    Custom,
}

impl std::fmt::Display for ApiProvider {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ApiProvider::OpenAI => write!(f, "OpenAI"),
            ApiProvider::Anthropic => write!(f, "Anthropic"),
            ApiProvider::Gemini => write!(f, "Gemini"),
            ApiProvider::Custom => write!(f, "Custom"),
        }
    }
}

/// API configuration
#[derive(Debug, Clone)]
pub struct ApiConfig {
    pub provider: ApiProvider,
    pub api_key: String,
    pub api_url: Option<String>,
    pub model: Option<String>,
}

/// Authentication configuration for GraphOS services
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthConfig {
    pub rpc_secret: Option<String>,
    pub endpoints: HashMap<String, EndpointConfig>,
}

/// Configuration for a specific endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EndpointConfig {
    pub url: String,
    pub secret: Option<String>,
    pub token: Option<String>,
    pub use_tls: Option<bool>,
}

/// File formats supported for configuration
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConfigFormat {
    Json,
    Yaml,
    Toml,
}

impl ConfigFormat {
    pub fn extension(&self) -> &'static str {
        match self {
            ConfigFormat::Json => "json",
            ConfigFormat::Yaml => "yaml",
            ConfigFormat::Toml => "toml",
        }
    }
    
    pub fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_lowercase().as_str() {
            "json" => Some(ConfigFormat::Json),
            "yaml" | "yml" => Some(ConfigFormat::Yaml),
            "toml" => Some(ConfigFormat::Toml),
            _ => None,
        }
    }
}

/// Full application configuration
#[derive(Debug, Clone)]
pub struct Config {
    pub apis: HashMap<ApiProvider, ApiConfig>,
    pub default_provider: Option<ApiProvider>,
    pub auth: Option<AuthConfig>,
}

impl Config {
    /// Load API configuration from environment variables
    async fn load_api_config() -> HashMap<ApiProvider, ApiConfig> {
        let mut apis = HashMap::new();
        
        // Check for OpenAI configuration
        if let Ok(api_key) = env::var("OPENAI_API_KEY") {
            let api_url = env::var("OPENAI_API_URL").ok();
            let model = env::var("OPENAI_API_MODEL").or_else(|_| Ok::<String, env::VarError>("gpt-4o".into())).ok();
            
            apis.insert(ApiProvider::OpenAI, ApiConfig {
                provider: ApiProvider::OpenAI,
                api_key,
                api_url,
                model,
            });
        }
        
        // Check for Anthropic configuration
        if let Ok(api_key) = env::var("ANTHROPIC_API_KEY") {
            let api_url = env::var("ANTHROPIC_API_URL").ok();
            let model = env::var("ANTHROPIC_API_MODEL").or_else(|_| Ok::<String, env::VarError>("claude-3-opus-20240229".into())).ok();
            
            apis.insert(ApiProvider::Anthropic, ApiConfig {
                provider: ApiProvider::Anthropic,
                api_key,
                api_url,
                model,
            });
        }
        
        // Check for Gemini configuration
        if let Ok(api_key) = env::var("GEMINI_API_KEY") {
            let api_url = env::var("GEMINI_API_URL").ok();
            let model = env::var("GEMINI_API_MODEL").or_else(|_| Ok::<String, env::VarError>("gemini-pro".into())).ok();
            
            apis.insert(ApiProvider::Gemini, ApiConfig {
                provider: ApiProvider::Gemini,
                api_key,
                api_url,
                model,
            });
        }
        
        // Check for custom API configuration
        if let Ok(api_key) = env::var("CUSTOM_API_KEY") {
            let api_url = env::var("CUSTOM_API_URL").ok();
            let model = env::var("CUSTOM_API_MODEL").ok();
            
            apis.insert(ApiProvider::Custom, ApiConfig {
                provider: ApiProvider::Custom,
                api_key,
                api_url,
                model,
            });
        }
        
        apis
    }
    
    /// Get the default API provider from environment variables
    fn get_default_provider(apis: &HashMap<ApiProvider, ApiConfig>) -> Option<ApiProvider> {
        // Set first available provider as default
        let mut default_provider = None;
        for provider in [ApiProvider::OpenAI, ApiProvider::Anthropic, ApiProvider::Gemini, ApiProvider::Custom] {
            if apis.contains_key(&provider) && default_provider.is_none() {
                default_provider = Some(provider);
            }
        }
        
        // Override default provider if explicitly set
        if let Ok(default) = env::var("DEFAULT_API_PROVIDER") {
            match default.to_lowercase().as_str() {
                "openai" => {
                    if apis.contains_key(&ApiProvider::OpenAI) {
                        default_provider = Some(ApiProvider::OpenAI);
                    }
                }
                "anthropic" => {
                    if apis.contains_key(&ApiProvider::Anthropic) {
                        default_provider = Some(ApiProvider::Anthropic);
                    }
                }
                "gemini" => {
                    if apis.contains_key(&ApiProvider::Gemini) {
                        default_provider = Some(ApiProvider::Gemini);
                    }
                }
                "custom" => {
                    if apis.contains_key(&ApiProvider::Custom) {
                        default_provider = Some(ApiProvider::Custom);
                    }
                }
                _ => {}
            }
        }
        
        default_provider
    }
    
    /// Get possible authentication config file paths
    fn get_auth_config_paths() -> Vec<(PathBuf, ConfigFormat)> {
        let mut paths = Vec::new();
        
        // System-wide config path
        if let Ok(sys_paths) = fs::read_dir("/etc/graph_os") {
            for path in sys_paths.filter_map(Result::ok) {
                let file_path = path.path();
                if let Some(ext) = file_path.extension().and_then(|e| e.to_str()) {
                    if let Some(format) = ConfigFormat::from_extension(ext) {
                        paths.push((file_path, format));
                    }
                }
            }
        }
        
        // User config paths
        if let Some(home_dir) = dirs::home_dir() {
            let user_config_dir = home_dir.join(".graph_os");
            
            if let Ok(user_paths) = fs::read_dir(&user_config_dir) {
                for path in user_paths.filter_map(Result::ok) {
                    let file_path = path.path();
                    if let Some(ext) = file_path.extension().and_then(|e| e.to_str()) {
                        if let Some(format) = ConfigFormat::from_extension(ext) {
                            paths.push((file_path, format));
                        }
                    }
                }
            }
            
            // Add specific config paths
            for format in [ConfigFormat::Json, ConfigFormat::Yaml, ConfigFormat::Toml] {
                let ext = format.extension();
                paths.push((user_config_dir.join(format!("config.{}", ext)), format));
            }
        }
        
        paths
    }
    
    /// Try to load auth config from a specific file
    fn load_auth_config_from_file(path: &Path, format: ConfigFormat) -> Result<AuthConfig> {
        let content = fs::read_to_string(path)
            .with_context(|| format!("Failed to read config file: {}", path.display()))?;
            
        match format {
            ConfigFormat::Json => {
                serde_json::from_str(&content)
                    .with_context(|| format!("Failed to parse JSON config file: {}", path.display()))
            },
            ConfigFormat::Yaml => {
                serde_yaml::from_str(&content)
                    .with_context(|| format!("Failed to parse YAML config file: {}", path.display()))
            },
            ConfigFormat::Toml => {
                toml::from_str(&content)
                    .with_context(|| format!("Failed to parse TOML config file: {}", path.display()))
            },
        }
    }
    
    /// Try to load authentication configuration from available files
    fn load_auth_config() -> Option<AuthConfig> {
        let config_paths = Self::get_auth_config_paths();
        
        for (path, format) in config_paths {
            if path.exists() {
                match Self::load_auth_config_from_file(&path, format) {
                    Ok(config) => {
                        return Some(config);
                    },
                    Err(err) => {
                        eprintln!("Error loading config from {}: {}", path.display(), err);
                    }
                }
            }
        }
        
        None
    }
    
    /// Load configuration from environment variables and config files
    pub async fn load() -> Self {
        let apis = Self::load_api_config().await;
        let default_provider = Self::get_default_provider(&apis);
        let auth = Self::load_auth_config();
        
        Self {
            apis,
            default_provider,
            auth,
        }
    }
    
    /// Get the API configuration for the specified provider
    pub fn get_api_config(&self, provider: ApiProvider) -> Option<ApiConfig> {
        self.apis.get(&provider).cloned()
    }
    
    /// Get the default API configuration
    pub fn get_default_api_config(&self) -> Option<ApiConfig> {
        self.default_provider.and_then(|provider| self.get_api_config(provider))
    }
    
    /// Get a list of available API providers
    pub fn available_providers(&self) -> Vec<ApiProvider> {
        self.apis.keys().cloned().collect()
    }
    
    /// Get the authentication secret for GraphOS RPC
    pub fn get_rpc_secret(&self) -> Option<String> {
        // First check if it's in the auth config
        if let Some(auth) = &self.auth {
            if let Some(secret) = &auth.rpc_secret {
                return Some(secret.clone());
            }
        }
        
        None
    }
    
    /// Get endpoint configuration for the specified endpoint name
    pub fn get_endpoint_config(&self, name: &str) -> Option<EndpointConfig> {
        self.auth.as_ref()
            .and_then(|auth| auth.endpoints.get(name).cloned())
    }
}

// Singleton configuration instance
#[derive(Clone)]
pub struct ConfigManager {
    config: Arc<Mutex<Option<Config>>>,
}

impl ConfigManager {
    pub fn instance() -> &'static Self {
        static INSTANCE: std::sync::OnceLock<ConfigManager> = std::sync::OnceLock::new();
        INSTANCE.get_or_init(|| ConfigManager {
            config: Arc::new(Mutex::new(None)),
        })
    }
    
    pub async fn load(&self) -> Result<Config> {
        let config = Config::load().await;
        
        // Store the config for future use
        let mut config_lock = self.config.lock().await;
        *config_lock = Some(config.clone());
        
        Ok(config)
    }
    
    pub async fn get_config(&self) -> Result<Config> {
        let config_lock = self.config.lock().await;
        if let Some(config) = &*config_lock {
            return Ok(config.clone());
        }
        
        // Config not loaded yet, load it
        drop(config_lock);
        self.load().await
    }
    
    /// Create a new, empty auth config file at the default location
    pub async fn create_default_auth_config(&self, format: ConfigFormat) -> Result<PathBuf> {
        let home_dir = dirs::home_dir()
            .ok_or_else(|| anyhow!("Could not determine home directory"))?;
        
        let config_dir = home_dir.join(".graph_os");
        
        // Create the directory if it doesn't exist
        if !config_dir.exists() {
            fs::create_dir_all(&config_dir)
                .context("Failed to create config directory")?;
        }
        
        let config_path = config_dir.join(format!("config.{}", format.extension()));
        
        // Create default auth config
        let default_auth = AuthConfig {
            rpc_secret: None,
            endpoints: HashMap::new(),
        };
        
        // Serialize config based on format
        let content = match format {
            ConfigFormat::Json => serde_json::to_string_pretty(&default_auth)
                .context("Failed to serialize config to JSON")?,
            ConfigFormat::Yaml => serde_yaml::to_string(&default_auth)
                .context("Failed to serialize config to YAML")?,
            ConfigFormat::Toml => toml::to_string(&default_auth)
                .context("Failed to serialize config to TOML")?,
        };
        
        // Write config to file
        fs::write(&config_path, content)
            .with_context(|| format!("Failed to write config to {}", config_path.display()))?;
        
        Ok(config_path)
    }
    
    /// Update the auth config with a new RPC secret
    pub async fn set_rpc_secret(&self, secret: &str, format: ConfigFormat) -> Result<PathBuf> {
        let home_dir = dirs::home_dir()
            .ok_or_else(|| anyhow!("Could not determine home directory"))?;
        
        let config_dir = home_dir.join(".graph_os");
        
        // Create the directory if it doesn't exist
        if !config_dir.exists() {
            fs::create_dir_all(&config_dir)
                .context("Failed to create config directory")?;
        }
        
        let config_path = config_dir.join(format!("config.{}", format.extension()));
        
        // Try to load existing config or create a new one
        let mut auth_config = if config_path.exists() {
            Config::load_auth_config_from_file(&config_path, format)
                .unwrap_or_else(|_| AuthConfig {
                    rpc_secret: None,
                    endpoints: HashMap::new(),
                })
        } else {
            AuthConfig {
                rpc_secret: None,
                endpoints: HashMap::new(),
            }
        };
        
        // Update config with new secret
        auth_config.rpc_secret = Some(secret.to_string());
        
        // Serialize config based on format
        let content = match format {
            ConfigFormat::Json => serde_json::to_string_pretty(&auth_config)
                .context("Failed to serialize config to JSON")?,
            ConfigFormat::Yaml => serde_yaml::to_string(&auth_config)
                .context("Failed to serialize config to YAML")?,
            ConfigFormat::Toml => toml::to_string(&auth_config)
                .context("Failed to serialize config to TOML")?,
        };
        
        // Write config to file
        fs::write(&config_path, content)
            .with_context(|| format!("Failed to write config to {}", config_path.display()))?;
        
        // Reload config
        self.load().await?;
        
        Ok(config_path)
    }
    
    /// Add or update an endpoint configuration
    pub async fn set_endpoint_config(&self, name: &str, endpoint: EndpointConfig, format: ConfigFormat) -> Result<PathBuf> {
        let home_dir = dirs::home_dir()
            .ok_or_else(|| anyhow!("Could not determine home directory"))?;
        
        let config_dir = home_dir.join(".graph_os");
        
        // Create the directory if it doesn't exist
        if !config_dir.exists() {
            fs::create_dir_all(&config_dir)
                .context("Failed to create config directory")?;
        }
        
        let config_path = config_dir.join(format!("config.{}", format.extension()));
        
        // Try to load existing config or create a new one
        let mut auth_config = if config_path.exists() {
            Config::load_auth_config_from_file(&config_path, format)
                .unwrap_or_else(|_| AuthConfig {
                    rpc_secret: None,
                    endpoints: HashMap::new(),
                })
        } else {
            AuthConfig {
                rpc_secret: None,
                endpoints: HashMap::new(),
            }
        };
        
        // Update config with new endpoint
        auth_config.endpoints.insert(name.to_string(), endpoint);
        
        // Serialize config based on format
        let content = match format {
            ConfigFormat::Json => serde_json::to_string_pretty(&auth_config)
                .context("Failed to serialize config to JSON")?,
            ConfigFormat::Yaml => serde_yaml::to_string(&auth_config)
                .context("Failed to serialize config to YAML")?,
            ConfigFormat::Toml => toml::to_string(&auth_config)
                .context("Failed to serialize config to TOML")?,
        };
        
        // Write config to file
        fs::write(&config_path, content)
            .with_context(|| format!("Failed to write config to {}", config_path.display()))?;
        
        // Reload config
        self.load().await?;
        
        Ok(config_path)
    }
}