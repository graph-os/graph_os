defmodule GraphOS.MCP.Client do
  @moduledoc """
  MCP client implementation for connecting to external MCP servers.

  This module provides an Agent-based client for connecting to MCP servers,
  initializing sessions, and executing tools.
  """

  require Logger

  @default_timeout 30_000

  @type client_state :: %{
    url: String.t(),
    session_id: String.t() | nil,
    protocol_version: String.t(),
    capabilities: map(),
    request_id: integer(),
    http_client: module(),
    server_info: map() | nil,
    server_capabilities: map() | nil
  }

  # Client API

  @doc """
  Create a new MCP client.

  ## Parameters

    * `url` - The URL of the MCP server
    * `opts` - Options for the client
      * `:protocol_version` - The MCP protocol version to use (default: "2024-03-01")
      * `:capabilities` - Client capabilities (default: %{})
      * `:http_client` - HTTP client module to use (default: HTTPoison)

  ## Examples

      iex> {:ok, client} = GraphOS.MCP.Client.new("http://localhost:4000/mcp")
      {:ok, #PID<0.123.0>}
  """
  def new(url, opts \\ []) do
    protocol_version = Keyword.get(opts, :protocol_version, "2024-03-01")
    capabilities = Keyword.get(opts, :capabilities, %{})
    http_client = Keyword.get(opts, :http_client, HTTPoison)

    initial_state = %{
      url: url,
      session_id: nil,
      protocol_version: protocol_version,
      capabilities: capabilities,
      http_client: http_client,
      request_id: 0,
      server_info: nil,
      server_capabilities: nil
    }

    Agent.start_link(fn -> initial_state end)
  end

  @doc """
  Initialize the MCP session.

  ## Parameters

    * `client` - The client pid
    * `session_id` - Optional session ID (generated if not provided)
    * `timeout` - Request timeout in milliseconds

  ## Examples

      iex> GraphOS.MCP.Client.initialize(client)
      {:ok, %{protocol_version: "2024-03-01", ...}}
  """
  def initialize(client, session_id \\ nil, timeout \\ @default_timeout) do
    session_id = session_id || generate_session_id()

    Agent.get_and_update(client, fn state ->
      request = %{
        jsonrpc: "2.0",
        id: state.request_id + 1,
        method: "initialize",
        params: %{
          protocolVersion: state.protocol_version,
          capabilities: state.capabilities
        }
      }

      case make_request(state, request, session_id) do
        {:ok, response} ->
          # Extract response data
          _protocol_version = Map.get(response, "protocolVersion")
          server_info = Map.get(response, "serverInfo")
          server_capabilities = Map.get(response, "capabilities", %{})

          # Update state
          updated_state = %{state |
            session_id: session_id,
            request_id: state.request_id + 1,
            server_info: server_info,
            server_capabilities: server_capabilities
          }

          {{:ok, response}, updated_state}

        {:error, _reason} = error ->
          {error, state}
      end
    end, timeout)
  end

  @doc """
  List available tools from the MCP server.

  ## Parameters

    * `client` - The client pid
    * `timeout` - Request timeout in milliseconds

  ## Examples

      iex> GraphOS.MCP.Client.list_tools(client)
      {:ok, [%{name: "echo", description: "Echoes back the input", ...}, ...]}
  """
  def list_tools(client, timeout \\ @default_timeout) do
    Agent.get_and_update(client, fn state ->
      if state.session_id == nil do
        {{:error, :not_initialized}, state}
      else
        request = %{
          jsonrpc: "2.0",
          id: state.request_id + 1,
          method: "listTools",
          params: %{}
        }

        case make_request(state, request, state.session_id) do
          {:ok, response} ->
            updated_state = %{state | request_id: state.request_id + 1}
            tools = Map.get(response, "tools", [])
            {{:ok, tools}, updated_state}

          {:error, _reason} = error ->
            {error, state}
        end
      end
    end, timeout)
  end

  @doc """
  Execute a tool on the MCP server.

  ## Parameters

    * `client` - The client pid
    * `tool_name` - The name of the tool to execute
    * `params` - Tool parameters
    * `timeout` - Request timeout in milliseconds

  ## Examples

      iex> GraphOS.MCP.Client.execute_tool(client, "echo", %{"message" => "Hello"})
      {:ok, %{echo: "Hello"}}
  """
  def execute_tool(client, tool_name, params, timeout \\ @default_timeout) do
    Agent.get_and_update(client, fn state ->
      if state.session_id == nil do
        {{:error, :not_initialized}, state}
      else
        request = %{
          jsonrpc: "2.0",
          id: state.request_id + 1,
          method: "executeTool",
          params: %{
            name: tool_name,
            parameters: params
          }
        }

        case make_request(state, request, state.session_id) do
          {:ok, response} ->
            updated_state = %{state | request_id: state.request_id + 1}
            result = Map.get(response, "result")
            {{:ok, result}, updated_state}

          {:error, _reason} = error ->
            {error, state}
        end
      end
    end, timeout)
  end

  @doc """
  Get the current session ID.

  ## Parameters

    * `client` - The client pid

  ## Examples

      iex> GraphOS.MCP.Client.session_id(client)
      "session_123"
  """
  def session_id(client) do
    Agent.get(client, fn state -> state.session_id end)
  end

  # Private functions

  defp make_request(state, request, session_id) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-MCP-Session", session_id}
    ]

    body = Jason.encode!(request)

    case state.http_client.post(state.url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            if Map.has_key?(response, "error") do
              {:error, response["error"]}
            else
              {:ok, response["result"]}
            end

          {:error, reason} ->
            {:error, {:invalid_json, reason}}
        end

      {:ok, %{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp generate_session_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end
