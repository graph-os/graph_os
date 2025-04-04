#[cfg(test)]
mod tests {
    use serde_json::json;
    use graph_os_cli::adapters::JsonRpcClient;

    // Unit test for creating a client
    #[test]
    fn test_client_creation() {
        let client = JsonRpcClient::new("example.com", 8080, false, None, None, None);
        assert_eq!(client.endpoint, "http://example.com:8080/api/jsonrpc");
        assert_eq!(client.api_key, None);
        assert_eq!(client.model, None);
        assert_eq!(client.rpc_secret, None);
        
        let secure_client = JsonRpcClient::new(
            "secure.example.com", 
            443, 
            true, 
            Some("test-key".to_string()), 
            Some("test-model".to_string()),
            Some("test-secret".to_string())
        );
        assert_eq!(secure_client.endpoint, "https://secure.example.com:443/api/jsonrpc");
        assert_eq!(secure_client.api_key, Some("test-key".to_string()));
        assert_eq!(secure_client.model, Some("test-model".to_string()));
        assert_eq!(secure_client.rpc_secret, Some("test-secret".to_string()));
        
        let custom_client = JsonRpcClient::with_endpoint(
            "https://api.example.com/v1".to_string(),
            Some("custom-key".to_string()),
            Some("custom-model".to_string()),
            Some("custom-secret".to_string())
        );
        assert_eq!(custom_client.endpoint, "https://api.example.com/v1");
        assert_eq!(custom_client.api_key, Some("custom-key".to_string()));
        assert_eq!(custom_client.model, Some("custom-model".to_string()));
        assert_eq!(custom_client.rpc_secret, Some("custom-secret".to_string()));
    }

    // Simple test for request object construction
    #[test]
    fn test_build_request() {
        let params = json!({
            "param1": "value1",
            "param2": 42
        });
        
        // Create a jsonrpc request
        let request = json!({
            "jsonrpc": "2.0",
            "method": "test.method",
            "params": params,
            "id": "test-id"
        });
        
        assert_eq!(request["jsonrpc"], "2.0");
        assert_eq!(request["method"], "test.method");
        assert_eq!(request["params"]["param1"], "value1");
        assert_eq!(request["params"]["param2"], 42);
    }
}

#[cfg(test)]
mod config_tests {
    use std::collections::HashMap;
    use serde_json;
    use graph_os_cli::config::{AuthConfig, EndpointConfig, ConfigFormat};
    
    #[test]
    fn test_auth_config_serialization() {
        // Create a test auth config
        let mut endpoints = HashMap::new();
        endpoints.insert("default".to_string(), EndpointConfig {
            url: "api.example.com".to_string(),
            secret: Some("endpoint-secret".to_string()),
            token: None,
            use_tls: Some(true),
        });
        
        let auth_config = AuthConfig {
            rpc_secret: Some("test-secret".to_string()),
            endpoints,
        };
        
        // Test JSON serialization
        let json = serde_json::to_string(&auth_config).unwrap();
        let deserialized: AuthConfig = serde_json::from_str(&json).unwrap();
        
        assert_eq!(deserialized.rpc_secret, Some("test-secret".to_string()));
        assert!(deserialized.endpoints.contains_key("default"));
        assert_eq!(
            deserialized.endpoints["default"].url,
            "api.example.com"
        );
        assert_eq!(
            deserialized.endpoints["default"].secret,
            Some("endpoint-secret".to_string())
        );
        assert_eq!(deserialized.endpoints["default"].use_tls, Some(true));
    }
    
    #[test]
    fn test_config_format() {
        // Test extension methods
        assert_eq!(ConfigFormat::Json.extension(), "json");
        assert_eq!(ConfigFormat::Yaml.extension(), "yaml");
        assert_eq!(ConfigFormat::Toml.extension(), "toml");
        
        // Test from_extension
        assert_eq!(ConfigFormat::from_extension("json"), Some(ConfigFormat::Json));
        assert_eq!(ConfigFormat::from_extension("JSON"), Some(ConfigFormat::Json));
        assert_eq!(ConfigFormat::from_extension("yaml"), Some(ConfigFormat::Yaml));
        assert_eq!(ConfigFormat::from_extension("yml"), Some(ConfigFormat::Yaml));
        assert_eq!(ConfigFormat::from_extension("toml"), Some(ConfigFormat::Toml));
        assert_eq!(ConfigFormat::from_extension("TOML"), Some(ConfigFormat::Toml));
        assert_eq!(ConfigFormat::from_extension("invalid"), None);
    }
}