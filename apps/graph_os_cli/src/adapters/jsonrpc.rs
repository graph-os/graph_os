use anyhow::Error;
use futures_util::StreamExt;
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, CONTENT_TYPE};
use reqwest::{Client, Response};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::sync::mpsc;
use uuid::Uuid;

/// A message role for conversation context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageRole {
    #[serde(rename = "user")]
    User,
    #[serde(rename = "assistant")]
    Assistant,
    #[serde(rename = "system")]
    System,
}

/// A message in a conversation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: MessageRole,
    pub content: String,
}

/// A JSONRPC client for communicating with the API over HTTP/2
#[derive(Clone)]
pub struct JsonRpcClient {
    client: Client,
    pub endpoint: String,
    pub api_key: Option<String>,
    pub model: Option<String>,
    pub rpc_secret: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    jsonrpc: String,
    method: String,
    params: Value,
    id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    jsonrpc: String,
    result: Option<Value>,
    error: Option<JsonRpcError>,
    id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JsonRpcStreamChunk {
    jsonrpc: String,
    result: Option<Value>,
    error: Option<JsonRpcError>,
    id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JsonRpcError {
    code: i32,
    message: String,
    data: Option<Value>,
}

impl JsonRpcClient {
    /// Create a new JSONRPC client
    pub fn new(host: &str, port: u16, use_https: bool, api_key: Option<String>, model: Option<String>, rpc_secret: Option<String>) -> Self {
        // Create a client with HTTP/2 enabled
        let client = Client::builder()
            .http2_prior_knowledge()  // Force HTTP/2
            .build()
            .expect("Failed to create HTTP client");

        // Construct the endpoint URL
        let scheme = if use_https { "https" } else { "http" };
        let endpoint = format!("{}://{}:{}/api/jsonrpc", scheme, host, port);

        Self { 
            client, 
            endpoint,
            api_key,
            model,
            rpc_secret,
        }
    }
    
    /// Create a new JSONRPC client from a custom endpoint
    pub fn with_endpoint(endpoint: String, api_key: Option<String>, model: Option<String>, rpc_secret: Option<String>) -> Self {
        // Create a client with HTTP/2 enabled
        let client = Client::builder()
            .http2_prior_knowledge()  // Force HTTP/2
            .build()
            .expect("Failed to create HTTP client");

        Self { 
            client, 
            endpoint,
            api_key,
            model,
            rpc_secret,
        }
    }

    /// Ping the server to check connectivity
    pub async fn ping(&self) -> Result<bool, Error> {
        match self.request("ping", json!({})).await {
            Ok(_) => Ok(true),
            Err(e) => {
                println!("Ping failed: {}", e);
                Ok(false)
            }
        }
    }

    /// Send a JSONRPC request to the server
    pub async fn request(&self, method: &str, params: Value) -> Result<Value, Error> {
        // Create a JSONRPC request
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: method.to_string(),
            params,
            id: Uuid::new_v4().to_string(),
        };

        // Create headers
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        headers.insert(ACCEPT, HeaderValue::from_static("application/json"));
        
        // Add API key if available for LLM services
        if let Some(api_key) = &self.api_key {
            if let Ok(header_value) = HeaderValue::from_str(&format!("Bearer {}", api_key)) {
                headers.insert("Authorization", header_value);
            }
        }
        
        // Add RPC secret for GraphOS authentication if available
        if let Some(rpc_secret) = &self.rpc_secret {
            if let Ok(header_value) = HeaderValue::from_str(&format!("Bearer {}", rpc_secret)) {
                headers.insert("X-GraphOS-Auth", header_value);
            }
        }

        // Send the request
        let response = self.client.post(&self.endpoint)
            .headers(headers)
            .json(&request)
            .send()
            .await?;
        
        // Check status code
        if !response.status().is_success() {
            return Err(anyhow::anyhow!("HTTP error: {}", response.status()));
        }
        
        // Parse the response as JSON
        let rpc_response: JsonRpcResponse = response.json().await?;
        
        // Handle the response
        if let Some(error) = rpc_response.error {
            return Err(anyhow::anyhow!("JSONRPC error: {} (code: {})", error.message, error.code));
        }
        
        // Return the result
        Ok(rpc_response.result.unwrap_or(json!(null)))
    }
    
    /// Send a streaming request and return chunks through a channel
    pub async fn request_streaming(
        &self, 
        method: &str, 
        params: Value,
        sender: mpsc::Sender<String>,
    ) -> Result<(), Error> {
        // Create a JSONRPC request
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: method.to_string(),
            params,
            id: Uuid::new_v4().to_string(),
        };

        // Create headers
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        headers.insert(ACCEPT, HeaderValue::from_static("application/json-seq"));
        
        // Add API key if available for LLM services
        if let Some(api_key) = &self.api_key {
            if let Ok(header_value) = HeaderValue::from_str(&format!("Bearer {}", api_key)) {
                headers.insert("Authorization", header_value);
            }
        }
        
        // Add RPC secret for GraphOS authentication if available
        if let Some(rpc_secret) = &self.rpc_secret {
            if let Ok(header_value) = HeaderValue::from_str(&format!("Bearer {}", rpc_secret)) {
                headers.insert("X-GraphOS-Auth", header_value);
            }
        }
        
        // Send the request
        let response = self.client.post(&self.endpoint)
            .headers(headers)
            .json(&request)
            .send()
            .await?;
        
        // Check status code
        if !response.status().is_success() {
            return Err(anyhow::anyhow!("HTTP error: {}", response.status()));
        }
        
        // Process the streaming response
        self.process_streaming_response(response, sender).await?;
        
        Ok(())
    }
    
    /// Process a streaming response from the server
    async fn process_streaming_response(
        &self,
        response: Response,
        sender: mpsc::Sender<String>,
    ) -> Result<(), Error> {
        let mut stream = response.bytes_stream();
        
        let mut buffer = Vec::new();
        
        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            buffer.extend_from_slice(&chunk);
            
            // Process any complete JSON objects in the buffer
            let mut start = 0;
            for (i, &byte) in buffer.iter().enumerate() {
                if byte == b'\n' {
                    if i > start {
                        let slice = &buffer[start..i];
                        if let Ok(chunk) = serde_json::from_slice::<JsonRpcStreamChunk>(slice) {
                            if let Some(result) = chunk.result {
                                if let Some(content) = result.get("content") {
                                    if let Some(text) = content.as_str() {
                                        // Send the content through the channel
                                        if sender.send(text.to_string()).await.is_err() {
                                            // Channel closed, stop processing
                                            return Ok(());
                                        }
                                    }
                                }
                            } else if let Some(error) = chunk.error {
                                return Err(anyhow::anyhow!("Stream error: {} (code: {})", error.message, error.code));
                            }
                        }
                    }
                    start = i + 1;
                }
            }
            
            // Remove processed data from buffer
            if start > 0 {
                buffer.drain(0..start);
            }
        }
        
        Ok(())
    }
    
    /// Send a conversation to the chat API
    pub async fn chat(
        &self, 
        messages: Vec<Message>,
        stream: bool,
        sender: Option<mpsc::Sender<String>>,
    ) -> Result<String, Error> {
        // Prepare the parameters
        let mut params = json!({
            "messages": messages,
            "stream": stream
        });
        
        // Add model if specified
        if let Some(model) = &self.model {
            params["model"] = json!(model);
        }
        
        if stream {
            // Handle streaming response
            if let Some(tx) = sender {
                self.request_streaming("chat", params, tx).await?;
                Ok("".to_string())
            } else {
                Err(anyhow::anyhow!("No channel provided for streaming response"))
            }
        } else {
            // Handle regular response
            let response = self.request("chat", params).await?;
            
            // Extract the message from the response
            match response.get("message") {
                Some(msg) => Ok(msg.as_str().unwrap_or("Response could not be parsed").to_string()),
                None => Ok("Received a response without a message field".to_string())
            }
        }
    }
}