defmodule GraphOS.Adapter do
  @moduledoc """
  Adapter system for GraphOS components.
  
  This module serves as an entry point to the adapter system, which allows GraphOS 
  components to be accessed through different communication protocols. The adapter
  system includes the following components:
  
  - `GraphAdapter`: Behavior for defining protocol adapters
  - `Context`: Request/response context that flows through the adapter pipeline
  - `PlugAdapter`: Middleware system for enhancing adapters
  - `Server`: GenServer implementation for adapter processes
  
  ## Common Adapters
  
  - `GenServer`: Direct Elixir integration via GenServer
  - `JSONRPC`: JSON-RPC 2.0 protocol adapter
  - `GRPC`: gRPC protocol adapter
  - `MCP`: Model Context Protocol adapter
  
  ## Example Usage
  
  ```elixir
  # Start a GenServer adapter
  {:ok, pid} = GraphOS.Adapter.GraphAdapter.start_link(
    adapter: GraphOS.Adapter.GenServer,
    name: GraphAdapter,
    plugs: [
      {AuthPlug, realm: "internal"},
      LoggingPlug
    ]
  )
  
  # Execute a query operation
  {:ok, result} = GraphOS.Adapter.GraphAdapter.execute(
    GraphAdapter,
    {:query, "nodes.list", %{type: "person"}}
  )
  ```
  """
  
  # This module is just a namespace, so we don't need any functions here.
  # The actual implementation is in the GraphAdapter, Context, and PlugAdapter modules.
end