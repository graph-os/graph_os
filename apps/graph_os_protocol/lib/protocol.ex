defmodule GraphOS.Protocol do
  @moduledoc """
  Protocol adapters for GraphOS components.
  
  This module serves as an entry point to the protocol adapters system, which allows GraphOS
  components to be accessed through different communication protocols. The protocol adapter
  system is built on top of the GraphOS.Adapter infrastructure and provides implementations
  for standard protocols.
  
  ## Available Protocols
  
  - `GraphOS.Protocol.Adapter`: Core adapter behavior and utilities
  - `GraphOS.Protocol.Plug`: Standard Plug implementation
  - `GraphOS.Protocol.JSONRPC`: JSON-RPC 2.0 protocol adapter
  - `GraphOS.Protocol.GRPC`: gRPC protocol adapter
  - `GraphOS.Protocol.MCP`: Model Context Protocol adapter
  
  ## Example Usage
  
  ```elixir
  # Start a JSON-RPC adapter
  {:ok, pid} = GraphOS.Protocol.JSONRPC.start_link(
    name: JSONRPCAdapter,
    plugs: [
      {AuthPlug, realm: "api"},
      LoggingPlug
    ]
  )
  
  # Process a JSON-RPC request
  request = %{
    "jsonrpc" => "2.0",
    "id" => 1,
    "method" => "graph.query.nodes.list",
    "params" => %{
      "filters" => %{
        "type" => "person"
      }
    }
  }
  
  {:ok, response} = GraphOS.Protocol.JSONRPC.process(JSONRPCAdapter, request)
  ```
  """
  
  use Boundary, deps: [:graph_os_core, :graph_os_graph, :mcp]
  
  # This module is just a namespace, so we don't need any functions here.
  # The actual implementation is in the adapter modules.
end