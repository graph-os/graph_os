use anyhow::{anyhow, Result};
use tonic::{transport::Channel, Request, transport::Uri};
use std::time::Duration;

// Include the generated Proto code
pub mod graph_os {
    tonic::include_proto!("graph_os");
}

use graph_os::system_info_service_client::SystemInfoServiceClient;
use graph_os::{GetSystemInfoRequest, ListSystemInfoRequest, SystemInfo, SystemInfoList};

/// GrpcClient for connecting to the GraphOS server
pub struct GrpcClient {
    client: SystemInfoServiceClient<Channel>,
}

impl GrpcClient {
    /// Create a new gRPC client
    pub async fn new(endpoint: &str) -> Result<Self> {
        println!("Creating gRPC client for endpoint: {}", endpoint);
        
        // Parse the endpoint as a URI
        let uri = endpoint.parse::<Uri>()?;
        
        println!("Connecting to gRPC server...");
        
        // Set up the channel with timeout and keepalive settings
        match Channel::builder(uri)
            .timeout(Duration::from_secs(10))  // Set a 10 second connection timeout
            .connect_timeout(Duration::from_secs(5))  // 5 second connect timeout
            .connect()
            .await {
                Ok(channel) => {
                    println!("Connected to gRPC endpoint");
                    let client = SystemInfoServiceClient::new(channel);
                    Ok(Self { client })
                },
                Err(e) => {
                    println!("Failed to connect to gRPC server: {}", e);
                    println!("Error details: {:?}", e);
                    Err(anyhow!("Connection error: {}", e))
                }
            }
    }

    /// Get current system information
    pub async fn get_system_info(&mut self) -> Result<SystemInfo> {
        let request = Request::new(GetSystemInfoRequest {});
        
        let response = self.client.get_system_info(request)
            .await
            .map_err(|e| anyhow!("gRPC error: {}", e))?;
            
        Ok(response.into_inner())
    }

    /// Get historical system information
    pub async fn list_system_info(&mut self, limit: Option<i32>, since: Option<i64>) -> Result<SystemInfoList> {
        let request = Request::new(ListSystemInfoRequest {
            limit: limit.unwrap_or(0),
            since: since.unwrap_or(0),
        });
        
        let response = self.client.list_system_info(request)
            .await
            .map_err(|e| anyhow!("gRPC error: {}", e))?;
            
        Ok(response.into_inner())
    }
}

/// Formats a SystemInfo for display
pub fn format_system_info(info: &SystemInfo) -> String {
    let mut output = String::new();
    
    output.push_str(&format!("Hostname:     {}\n", info.hostname));
    output.push_str(&format!("Platform:     {} ({})\n", info.platform, info.architecture));
    output.push_str(&format!("OS Version:   {}\n", info.os_version));
    output.push_str(&format!("Uptime:       {} seconds\n", info.uptime));
    output.push_str(&format!("CPU Cores:    {}\n", info.cpu_count));
    
    // CPU load is only available on Unix systems
    if info.cpu_load_1m > 0.0 {
        output.push_str(&format!("CPU Load:     {:.2}% (1m), {:.2}% (5m), {:.2}% (15m)\n", 
            info.cpu_load_1m, info.cpu_load_5m, info.cpu_load_15m));
    }
    
    // Memory info (convert to MB for readability)
    let total_mb = info.memory_total / (1024 * 1024);
    let used_mb = info.memory_used / (1024 * 1024);
    let free_mb = info.memory_free / (1024 * 1024);
    
    output.push_str(&format!("Memory:       {}MB total, {}MB used, {}MB free\n", 
        total_mb, used_mb, free_mb));
    
    output
}