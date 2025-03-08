defmodule GraphOS.MCP.Service.Server do
  @moduledoc """
  MCP (Model Context Protocol) server implementation for GraphOS.

  This server implements the MCP protocol for AI/LLM integration with GraphOS.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Initialize server state
    state = %{
      tools: %{},
      sessions: %{},
      protocol_version: "2024-03-01"
    }

    # Register default tools
    state = register_default_tools(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:initialize, session_id, capabilities}, _from, state) do
    # Add session
    sessions = Map.put(state.sessions, session_id, %{
      id: session_id,
      capabilities: capabilities,
      created_at: DateTime.utc_now()
    })

    # Return protocol info
    response = %{
      protocol_version: state.protocol_version,
      server_info: %{
        name: "GraphOS.MCP",
        version: "0.1.0"
      },
      capabilities: %{
        tools: true
      }
    }

    {:reply, {:ok, response}, %{state | sessions: sessions}}
  end

  @impl true
  def handle_call({:list_tools, session_id}, _from, state) do
    # Check if session exists
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      _session ->
        # Return list of available tools
        tools = Map.values(state.tools)
        |> Enum.map(fn %{name: name, description: description, parameters: params} ->
          %{name: name, description: description, parameters: params}
        end)

        {:reply, {:ok, tools}, state}
    end
  end

  @impl true
  def handle_call({:execute_tool, session_id, tool_name, params}, _from, state) do
    # Check if session exists
    with %{} <- Map.get(state.sessions, session_id) || :session_not_found,
         %{handler: handler} <- Map.get(state.tools, tool_name) || :tool_not_found do

      # Execute the tool handler
      try do
        result = handler.(params)
        {:reply, {:ok, result}, state}
      rescue
        e ->
          {:reply, {:error, "Tool execution failed: #{inspect(e)}"}, state}
      end
    else
      :session_not_found ->
        {:reply, {:error, :session_not_found}, state}

      :tool_not_found ->
        {:reply, {:error, :tool_not_found}, state}
    end
  end

  # Tool registration

  @impl true
  def handle_call({:register_tool, tool_spec}, _from, state) do
    %{name: name} = tool_spec

    # Add tool to tools map
    tools = Map.put(state.tools, name, tool_spec)

    {:reply, :ok, %{state | tools: tools}}
  end

  # Private functions

  defp register_default_tools(state) do
    # Echo tool for testing
    echo_tool = %{
      name: "echo",
      description: "Echoes back the input",
      parameters: %{
        type: "object",
        properties: %{
          message: %{
            type: "string",
            description: "Message to echo"
          }
        },
        required: ["message"]
      },
      handler: fn %{"message" => message} -> %{echo: message} end
    }

    # Graph query tool
    graph_query_tool = %{
      name: "graph_query",
      description: "Query the graph database",
      parameters: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Graph query string"
          }
        },
        required: ["query"]
      },
      handler: fn %{"query" => _query} ->
        # This would actually query the graph, but for now return sample data
        %{results: [%{id: "node1", label: "Person", properties: %{name: "Alice"}}]}
      end
    }

    # Register tools
    tools = state.tools
    |> Map.put(echo_tool.name, echo_tool)
    |> Map.put(graph_query_tool.name, graph_query_tool)

    %{state | tools: tools}
  end

  # Public API

  @doc """
  Initialize a new MCP session.

  ## Parameters

    * `session_id` - The session identifier
    * `capabilities` - Client capabilities

  ## Examples

      iex> GraphOS.MCP.Service.Server.initialize("session1", %{})
      {:ok, %{protocol_version: "2024-03-01", server_info: %{...}, capabilities: %{...}}}
  """
  def initialize(session_id, capabilities \\ %{}) do
    GenServer.call(__MODULE__, {:initialize, session_id, capabilities})
  end

  @doc """
  List available tools for a session.

  ## Parameters

    * `session_id` - The session identifier

  ## Examples

      iex> GraphOS.MCP.Service.Server.list_tools("session1")
      {:ok, [%{name: "echo", description: "Echoes back the input", parameters: %{...}}, ...]}
  """
  def list_tools(session_id) do
    GenServer.call(__MODULE__, {:list_tools, session_id})
  end

  @doc """
  Execute a tool.

  ## Parameters

    * `session_id` - The session identifier
    * `tool_name` - The name of the tool to execute
    * `params` - Tool parameters

  ## Examples

      iex> GraphOS.MCP.Service.Server.execute_tool("session1", "echo", %{"message" => "Hello"})
      {:ok, %{echo: "Hello"}}
  """
  def execute_tool(session_id, tool_name, params) do
    GenServer.call(__MODULE__, {:execute_tool, session_id, tool_name, params})
  end

  @doc """
  Register a new tool.

  ## Parameters

    * `tool_spec` - The tool specification

  ## Examples

      iex> tool_spec = %{name: "my_tool", description: "My custom tool", parameters: %{...}, handler: fn params -> ... end}
      iex> GraphOS.MCP.Service.Server.register_tool(tool_spec)
      :ok
  """
  def register_tool(tool_spec) do
    GenServer.call(__MODULE__, {:register_tool, tool_spec})
  end
end
