defmodule GraphOS.Protocol.Schema do
  @moduledoc """
  Protocol schema utilities for the upgradable protocol system.

  This module provides utilities for working with protocol schemas based on Protocol Buffers.
  It integrates with the GraphOS.Store.Schema system, using protobuf as the canonical
  schema definition.

  The Protocol Schema system allows upgrading between different protocols:
  - gRPC (native protocol buffer format)
  - JSON-RPC (upgraded from protobuf)
  - Plug/HTTP (upgraded from protobuf)
  - Model Context Protocol (upgraded from protobuf)

  ## Integration with GraphOS.Store.Schema

  The Protocol Schema system uses GraphOS.Store.Schema as the canonical source of
  schema definitions. The schema system uses protobuf definitions directly
  as the source of truth for all protocol formats.

  ## Protocol Upgrading

  Protocol upgrading is the process of converting between different protocol formats
  while preserving the original semantics and type safety. For example:

  1. A gRPC request comes in with a Protocol Buffer message
  2. The system processes it and generates a Protocol Buffer response
  3. If needed, this response can be "upgraded" to JSON-RPC, Plug, or MCP format

  This allows services to communicate using their preferred protocol while
  maintaining a single canonical schema definition.
  """

  alias GraphOS.Store.Schema.Protobuf

  @doc """
  Upgrades a Protocol Buffer message to JSON-RPC format.

  ## Parameters

    * `proto_msg` - The Protocol Buffer message to upgrade
    * `rpc_name` - The name of the RPC method
    * `schema_module` - The Schema module that defines the message types

  ## Returns

    * `map()` - The message in JSON-RPC format
  """
  @spec upgrade_to_jsonrpc(struct(), String.t(), module()) :: map()
  def upgrade_to_jsonrpc(proto_msg, rpc_name, schema_module) do
    # For test mocks, delegate to the mock schema module directly
    if function_exported?(schema_module, :upgrade_to_jsonrpc, 2) do
      schema_module.upgrade_to_jsonrpc(proto_msg, rpc_name)
    else
      # For real implementations, use the proper Protobuf module
      # Get the protobuf definition from the schema module
      proto_def = Protobuf.get_proto_definition(schema_module, proto_msg.__struct__)

      # Convert the proto message to a map
      params = Protobuf.proto_to_map(proto_msg, proto_def)

      # Determine the method name based on RPC method
      method = determine_jsonrpc_method(rpc_name)

      # Construct the JSON-RPC message
      %{
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params
      }
    end
  end

  @doc """
  Upgrades a Protocol Buffer message to Plug format.

  ## Parameters

    * `proto_msg` - The Protocol Buffer message to upgrade
    * `rpc_name` - The name of the RPC method
    * `schema_module` - The Schema module that defines the message types

  ## Returns

    * `map()` - The message in Plug format (path_params, query_params, body_params)
  """
  @spec upgrade_to_plug(struct(), String.t(), module()) :: map()
  def upgrade_to_plug(proto_msg, rpc_name, schema_module) do
    # For test mocks, delegate to the mock schema module directly
    if function_exported?(schema_module, :upgrade_to_plug, 2) do
      schema_module.upgrade_to_plug(proto_msg, rpc_name)
    else
      # Get the protobuf definition from the schema module
      proto_def = Protobuf.get_proto_definition(schema_module, proto_msg.__struct__)

      # Convert the proto message to a map
      params = Protobuf.proto_to_map(proto_msg, proto_def)

      # Analyze the parameters to determine which should go where
      {path_params, query_params, remaining} = extract_plug_params(params, rpc_name)

      # Return the plug parameters
      %{
        path_params: path_params,
        query_params: query_params,
        body_params: remaining
      }
    end
  end

  @doc """
  Upgrades a Protocol Buffer message to Model Context Protocol format.

  ## Parameters

    * `proto_msg` - The Protocol Buffer message to upgrade
    * `rpc_name` - The name of the RPC method
    * `schema_module` - The Schema module that defines the message types

  ## Returns

    * `map()` - The message in MCP format
  """
  @spec upgrade_to_mcp(struct(), String.t(), module()) :: map()
  def upgrade_to_mcp(proto_msg, rpc_name, schema_module) do
    # For test mocks, delegate to the mock schema module directly
    if function_exported?(schema_module, :upgrade_to_mcp, 2) do
      schema_module.upgrade_to_mcp(proto_msg, rpc_name)
    else
      # Get the protobuf definition from the schema module
      proto_def = Protobuf.get_proto_definition(schema_module, proto_msg.__struct__)

      # Convert the proto message to a map
      params = Protobuf.proto_to_map(proto_msg, proto_def)

      # Determine the MCP type and construct the message
      %{
        "type" => determine_mcp_type(rpc_name),
        "context" => %{
          "protocol" => "grpc",
          "method" => rpc_name
        },
        "data" => params
      }
    end
  end

  # Helper functions

  # Extract plug parameters from a map of parameters
  defp extract_plug_params(params, rpc_name) do
    # Default behavior - identify path, query, and body params
    # based on common conventions

    # Path parameters typically include ID for GET operations
    path_params =
      cond do
        String.starts_with?(rpc_name, "Get") && Map.has_key?(params, "id") ->
          resource = determine_resource_type(rpc_name)
          %{"path" => "#{resource}/#{Map.get(params, "id")}"}

        String.starts_with?(rpc_name, "List") || String.starts_with?(rpc_name, "Find") ->
          resource = determine_resource_type(rpc_name)
          %{"path" => "#{resource}"}

        String.starts_with?(rpc_name, "Create") ->
          resource = determine_resource_type(rpc_name)
          %{"path" => "#{resource}"}

        String.starts_with?(rpc_name, "Update") && Map.has_key?(params, "id") ->
          resource = determine_resource_type(rpc_name)
          %{"path" => "#{resource}/#{Map.get(params, "id")}"}

        String.starts_with?(rpc_name, "Delete") && Map.has_key?(params, "id") ->
          resource = determine_resource_type(rpc_name)
          %{"path" => "#{resource}/#{Map.get(params, "id")}"}

        true ->
          %{}
      end

    # Query parameters typically include filters, pagination, etc.
    query_param_keys = ["limit", "offset", "cursor", "sort", "order", "filter", "type"]
    {query_params, remaining} = Map.split(params, query_param_keys)

    # Remove id from remaining params if it's in path_params
    remaining =
      if path_params["path"] && String.contains?(path_params["path"], Map.get(params, "id", "")) do
        Map.delete(remaining, "id")
      else
        remaining
      end

    {path_params, query_params, remaining}
  end

  # Determine the resource type from an RPC name
  defp determine_resource_type(rpc_name) do
    rpc_name
    |> String.replace(~r/^(Get|List|Find|Create|Update|Delete|Add)/, "")
    |> String.replace(~r/Request$/, "")
    |> Macro.underscore()
    |> String.replace("_", "")
    |> String.downcase()
  end

  # Determine the JSON-RPC method name from an RPC name
  defp determine_jsonrpc_method(rpc_name) do
    cond do
      String.starts_with?(rpc_name, "Get") or String.starts_with?(rpc_name, "List") or
          String.starts_with?(rpc_name, "Find") ->
        "graph.query." <> format_method_path(rpc_name)

      String.starts_with?(rpc_name, "Create") or String.starts_with?(rpc_name, "Update") or
        String.starts_with?(rpc_name, "Delete") or String.starts_with?(rpc_name, "Add") ->
        "graph.action." <> format_method_path(rpc_name)

      true ->
        "graph.method." <> format_method_path(rpc_name)
    end
  end

  # Determine the MCP type from an RPC name
  defp determine_mcp_type(rpc_name) do
    rpc_name
    |> String.replace(~r/^(Get|List|Find|Create|Update|Delete|Add)/, "")
    |> String.replace(~r/Request$/, "")
  end

  # Format a method path from an RPC name
  defp format_method_path(rpc_name) do
    rpc_name
    |> String.replace(~r/^(Get|List|Find|Create|Update|Delete|Add)/, "")
    |> String.replace(~r/Request$/, "")
    |> Macro.underscore()
    |> String.replace("_", ".")
  end
end
