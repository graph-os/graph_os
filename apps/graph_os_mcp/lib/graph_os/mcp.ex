defmodule GraphOS.MCP do
  @moduledoc """
  GraphOS Model Context Protocol (MCP) implementation.

  This module provides a high-level API for working with MCP servers and clients in GraphOS.
  MCP allows AI/LLM models to interact with GraphOS through a defined protocol.

  For more information about the Model Context Protocol, visit:
  [Model Context Protocol Documentation](https://modelcontextprotocol.io/introduction)
  """

  alias GraphOS.MCP.Service.Server, as: MCPServer

  @doc """
  Start a new MCP session.

  ## Parameters

    * `session_id` - The session identifier (will be generated if not provided)
    * `capabilities` - Client capabilities

  ## Examples

      iex> result = GraphOS.MCP.start_session()
      iex> match?({:ok, session_id, _} when is_binary(session_id), result) or match?({:error, _}, result)
      true

      iex> result = GraphOS.MCP.start_session("my_custom_session")
      iex> match?({:ok, "my_custom_session", _}, result) or match?({:error, _}, result)
      true
  """
  def start_session(session_id \\ nil, capabilities \\ %{}) do
    session_id = session_id || generate_session_id()
    case MCPServer.initialize(session_id, capabilities) do
      {:ok, response} -> {:ok, session_id, response}
      error -> error
    end
  end

  @doc """
  List available tools for a session.

  ## Parameters

    * `session_id` - The session identifier

  ## Examples

      iex> result = GraphOS.MCP.list_tools("session_123")
      iex> match?({:ok, _}, result) or match?({:error, _}, result)
      true
  """
  def list_tools(session_id) do
    MCPServer.list_tools(session_id)
  end

  @doc """
  Execute a tool in an MCP session.

  ## Parameters

    * `session_id` - The session identifier
    * `tool_name` - The name of the tool to execute
    * `params` - Tool parameters

  ## Examples

      iex> result = GraphOS.MCP.execute_tool("session_123", "echo", %{"message" => "Hello"})
      iex> match?({:ok, _}, result) or match?({:error, _}, result)
      true
  """
  def execute_tool(session_id, tool_name, params) do
    MCPServer.execute_tool(session_id, tool_name, params)
  end

  @doc """
  Register a new tool with the MCP server.

  ## Parameters

    * `tool_spec` - The tool specification including name, description, parameters, and handler

  ## Examples

      iex> tool_spec = %{
      ...>   name: "my_tool",
      ...>   description: "My custom tool",
      ...>   parameters: %{type: "object", properties: %{message: %{type: "string"}}},
      ...>   handler: fn _params -> {:ok, %{result: "success"}} end
      ...> }
      iex> GraphOS.MCP.register_tool(tool_spec)
      :ok
  """
  def register_tool(tool_spec) do
    MCPServer.register_tool(tool_spec)
  end

  @doc """
  Create a client for connecting to an external MCP server.

  ## Parameters

    * `url` - The URL of the MCP server
    * `opts` - Options for the client

  ## Examples

      iex> result = GraphOS.MCP.client("http://localhost:4000/mcp")
      iex> match?({:ok, _}, result)
      true
  """
  def client(url, opts \\ []) do
    GraphOS.MCP.Client.new(url, opts)
  end

  # Helper functions

  @doc false
  defp generate_session_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end
