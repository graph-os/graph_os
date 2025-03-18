#[cfg(test)]
mod cli_tests {
    use clap::Parser;
    use graph_os_cli::cli::{Cli, Commands, ConfigCommands};
    
    #[test]
    fn test_cli_basic_options() {
        let cli = Cli::parse_from(&["gos", "--api-host", "test.example.com", "--api-port", "4321"]);
        
        assert_eq!(cli.api_host, "test.example.com");
        assert_eq!(cli.api_port, 4321);
        assert_eq!(cli.use_https, false);
        assert_eq!(cli.provider, None);
        assert_eq!(cli.model, None);
        assert_eq!(cli.session, None);
        assert!(matches!(cli.command, None));
    }
    
    #[test]
    fn test_cli_https_flag() {
        let cli = Cli::parse_from(&["gos", "--use-https"]);
        
        assert_eq!(cli.use_https, true);
    }
    
    #[test]
    fn test_cli_provider_and_model() {
        let cli = Cli::parse_from(&["gos", "--provider", "anthropic", "--model", "claude-3-opus"]);
        
        assert_eq!(cli.provider, Some("anthropic".to_string()));
        assert_eq!(cli.model, Some("claude-3-opus".to_string()));
    }
    
    #[test]
    fn test_cli_session() {
        let cli = Cli::parse_from(&["gos", "--session", "123e4567-e89b-12d3-a456-426614174000"]);
        
        assert!(cli.session.is_some());
        assert_eq!(cli.session.unwrap().to_string(), "123e4567-e89b-12d3-a456-426614174000");
    }
    
    #[test]
    fn test_cli_list_command() {
        let cli = Cli::parse_from(&["gos", "list"]);
        
        assert!(matches!(cli.command, Some(Commands::List)));
    }
    
    #[test]
    fn test_cli_show_command() {
        let cli = Cli::parse_from(&["gos", "show", "123e4567-e89b-12d3-a456-426614174000"]);
        
        if let Some(Commands::Show { id }) = cli.command {
            assert_eq!(id.to_string(), "123e4567-e89b-12d3-a456-426614174000");
        } else {
            panic!("Expected Show command");
        }
    }
    
    #[test]
    fn test_cli_config_init_command() {
        let cli = Cli::parse_from(&["gos", "config", "init"]);
        
        if let Some(Commands::Config { action }) = cli.command {
            assert!(matches!(action, ConfigCommands::Init { format } if format == "toml"));
        } else {
            panic!("Expected Config command with Init action");
        }
        
        // Test format option
        let cli_json = Cli::parse_from(&["gos", "config", "init", "--format", "json"]);
        
        if let Some(Commands::Config { action }) = cli_json.command {
            assert!(matches!(action, ConfigCommands::Init { format } if format == "json"));
        } else {
            panic!("Expected Config command with Init action");
        }
    }
    
    #[test]
    fn test_cli_config_set_secret_command() {
        let cli = Cli::parse_from(&["gos", "config", "set-secret", "test-secret"]);
        
        if let Some(Commands::Config { action }) = cli.command {
            assert!(matches!(action, ConfigCommands::SetSecret { secret, format } 
                              if secret == "test-secret" && format == "toml"));
        } else {
            panic!("Expected Config command with SetSecret action");
        }
    }
    
    #[test]
    fn test_cli_config_set_endpoint_command() {
        let cli = Cli::parse_from(&[
            "gos", "config", "set-endpoint", "test-endpoint", 
            "--url", "api.example.com", 
            "--secret", "endpoint-secret",
            "--use-tls"
        ]);
        
        if let Some(Commands::Config { action }) = cli.command {
            match action {
                ConfigCommands::SetEndpoint { name, url, secret, use_tls, format } => {
                    assert_eq!(name, "test-endpoint");
                    assert_eq!(url, "api.example.com");
                    assert_eq!(secret, Some("endpoint-secret".to_string()));
                    assert_eq!(use_tls, true);
                    assert_eq!(format, "toml");
                },
                _ => panic!("Expected SetEndpoint action")
            }
        } else {
            panic!("Expected Config command");
        }
    }
    
    #[test]
    fn test_cli_config_show_command() {
        let cli = Cli::parse_from(&["gos", "config", "show"]);
        
        if let Some(Commands::Config { action }) = cli.command {
            assert!(matches!(action, ConfigCommands::Show));
        } else {
            panic!("Expected Config command with Show action");
        }
    }
}