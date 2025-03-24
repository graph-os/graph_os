pub mod jsonrpc;
pub mod grpc;

// Re-export types for easier imports elsewhere
pub use jsonrpc::JsonRpcClient;
pub use jsonrpc::Message;
pub use jsonrpc::MessageRole;
pub use grpc::GrpcClient;