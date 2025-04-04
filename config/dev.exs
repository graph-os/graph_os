import Config

# CodeGraph service is disabled during refactoring
config :graph_os_core,
  enable_code_graph: false,
  watch_directories: ["apps/graph_os_core/lib", "apps/graph_os_dev/lib", "apps/graph_os_store/lib"],
  file_pattern: "**/*.ex",
  exclude_pattern: nil,
  auto_reload: false,
  poll_interval: 1000,
  distributed: false

# Configure query module for the GraphController
config :graph_os_dev,
  query_module: GraphOS.Graph.Query

# Configure protocol RPC secret and ports for development
# In production, this should be set via env vars in runtime.exs
config :graph_os_protocol, :auth,
  rpc_secret: "dev_only_8c5f243ed96a55ea767e41e75e2c38f09b07cec8",
  required: true

# Configure protocol server ports
config :graph_os_protocol, :grpc,
  port: 50051

config :graph_os_protocol, :jsonrpc,
  port: 4000
