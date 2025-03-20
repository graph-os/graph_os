use clap::Parser;
use graph_os_cli::cli::{Cli, Commands, SystemInfoCommands};
use graph_os_cli::adapters::GrpcClient;
use tokio::net::TcpStream;
use tokio::io::AsyncWriteExt;
use std::time::Duration;
use std::error::Error;
use anyhow::Result as AnyhowResult;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Parse command line arguments
    let cli = Cli::parse();
    
    match &cli.command {
        Some(Commands::SystemInfo { action }) => {
            handle_system_info(&cli, action).await?;
        },
        _ => {
            // Default - test gRPC connection
            println!("Testing gRPC connection to {}:{}", cli.api_host, cli.grpc_port);
            test_grpc_connection(&cli.api_host, cli.grpc_port).await?;
        }
    }
    
    Ok(())
}

// Handle system info commands
async fn handle_system_info(cli: &Cli, action: &Option<SystemInfoCommands>) -> Result<(), Box<dyn Error>> {
    let endpoint = format!("http://{}:{}", cli.api_host, cli.grpc_port);
    println!("Connecting to gRPC endpoint: {}", endpoint);
    
    // Create gRPC client
    let mut client = match GrpcClient::new(&endpoint).await {
        Ok(client) => client,
        Err(e) => {
            println!("Failed to create gRPC client: {}", e);
            return Err(Box::new(e));
        }
    };
    
    // Handle different system info actions
    match action {
        Some(SystemInfoCommands::Current) => {
            // Get current system info
            match client.get_system_info().await {
                Ok(info) => {
                    println!("\nSystem Information:");
                    println!("==================");
                    println!("{}", graph_os_cli::adapters::grpc::format_system_info(&info));
                },
                Err(e) => {
                    println!("Error getting system info: {}", e);
                    return Err(e);
                }
            }
        },
        Some(SystemInfoCommands::History { limit, since }) => {
            // Get historical system info
            match client.list_system_info(*limit, *since).await {
                Ok(info_list) => {
                    println!("\nHistorical System Information:");
                    println!("=============================");
                    println!("Returned {} records", info_list.items.len());
                    
                    for (i, info) in info_list.items.iter().enumerate() {
                        println!("\nRecord {}/{}:", i+1, info_list.items.len());
                        println!("{}", graph_os_cli::adapters::grpc::format_system_info(info));
                    }
                },
                Err(e) => {
                    println!("Error getting historical system info: {}", e);
                    return Err(e);
                }
            }
        },
        None => {
            // Default to current system info
            match client.get_system_info().await {
                Ok(info) => {
                    println!("\nSystem Information:");
                    println!("==================");
                    println!("{}", graph_os_cli::adapters::grpc::format_system_info(&info));
                },
                Err(e) => {
                    println!("Error getting system info: {}", e);
                    return Err(e);
                }
            }
        }
    }
    
    Ok(())
}

// Basic gRPC connection test
async fn test_grpc_connection(host: &str, port: u16) -> Result<(), Box<dyn Error>> {
    println!("Attempting to connect to {}:{}...", host, port);
    
    match TcpStream::connect(format!("{}:{}", host, port)).await {
        Ok(mut stream) => {
            println!("Successfully connected to the server!");
            
            // Try sending an HTTP2 header (simplified)
            let http2_preface = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";
            stream.write_all(http2_preface).await?;
            
            // Wait for a moment
            tokio::time::sleep(Duration::from_secs(1)).await;
            
            println!("HTTP/2 preface sent, connection seems to be working");
            
            // Try using the actual gRPC client
            let endpoint = format!("http://{}:{}", host, port);
            println!("Trying to initialize gRPC client for {}", endpoint);
            
            match GrpcClient::new(&endpoint).await {
                Ok(_) => println!("gRPC client successfully initialized!"),
                Err(e) => println!("gRPC client initialization failed: {}", e)
            }
            
            Ok(())
        },
        Err(e) => {
            println!("Failed to connect: {}", e);
            Err(Box::new(e))
        }
    }
}