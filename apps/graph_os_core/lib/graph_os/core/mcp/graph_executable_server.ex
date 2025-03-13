defmodule GraphOS.Core.MCP.GraphExecutableServer do
  @moduledoc """
  MCP Server implementation for executable graph nodes.

  This module provides an MCP interface to the graph execution system,
  allowing AI agents to discover and execute nodes in the graph.
  """

  use MCP.Server
  require Logger

  alias GraphOS.Graph
  alias GraphOS.Core.Executable
  alias GraphOS.Core.AccessControl
  alias SSE.ConnectionRegistry

  @impl true
  def start(session_id) do
    # Call the parent's start method
    super(session_id)
    
    # Initialize the graph system
    GraphOS.Graph.init(access_control: true)
    
    # Create a default user if none exists
    setup_default_permissions(session_id)
    
    :ok
  end

  @impl true
  def handle_initialize(session_id, request_id, params) do
    # Use the default initialize implementation, but capture the client info
    case super(session_id, request_id, params) do
      {:ok, result} -> 
        # Store the client info in the session data
        client_info = Map.get(params, "clientInfo", %{})
        actor_id = Map.get(client_info, "id", "default:user")
        
        # Update the session data with the actor ID
        ConnectionRegistry.update_data(session_id, %{
          actor_id: actor_id
        })
        
        # Make sure this actor exists in the graph
        if actor_id != "default:user" do
          AccessControl.define_actor(GraphOS.Graph, actor_id, %{
            name: Map.get(client_info, "name", actor_id),
            type: "user",
            created_at: DateTime.utc_now()
          })
        end
        
        {:ok, result}
        
      error -> error
    end
  end

  @impl true
  def handle_list_tools(session_id, request_id, params) do
    # Get the base tools from the parent
    {:ok, base_result} = super(session_id, request_id, params)
    
    # Add tools for graph node execution
    graph_tools = [
      %{
        name: "graph.execute",
        description: "Execute a node in the graph",
        inputSchema: %{
          type: "object",
          properties: %{
            node_id: %{
              type: "string",
              description: "ID of the node to execute"
            },
            context: %{
              type: "object",
              description: "Context data for execution"
            }
          },
          required: ["node_id"]
        }
      },
      %{
        name: "graph.query",
        description: "Query the graph for nodes",
        inputSchema: %{
          type: "object",
          properties: %{
            query: %{
              type: "object",
              description: "Query parameters"
            }
          },
          required: ["query"]
        }
      },
      %{
        name: "graph.create_executable",
        description: "Create an executable node in the graph",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{
              type: "string",
              description: "ID for the new node"
            },
            name: %{
              type: "string",
              description: "Human-readable name for the node"
            },
            executable_type: %{
              type: "string",
              description: "Type of executable (elixir_code, http_request, shell_command)",
              enum: ["elixir_code", "http_request", "shell_command"]
            },
            executable: %{
              type: "string", 
              description: "Executable code or configuration"
            },
            metadata: %{
              type: "object",
              description: "Additional metadata for the node"
            }
          },
          required: ["id", "executable_type", "executable"]
        }
      }
    ]
    
    # Merge the tools lists
    updated_tools = Map.update!(base_result, :tools, fn tools -> 
      tools ++ graph_tools
    end)
    
    {:ok, updated_tools}
  end

  @impl true
  def handle_tool_call(session_id, request_id, tool_name, arguments) when tool_name == "graph.execute" do
    Logger.info("Handling graph.execute tool call", 
      session_id: session_id, 
      request_id: request_id
    )
    
    # Extract parameters
    node_id = arguments["node_id"]
    context = arguments["context"] || %{}
    
    # Get the actor ID from the session
    {:ok, session_data} = MCP.Server.get_session_data(session_id)
    actor_id = Map.get(session_data, :actor_id, "default:user")
    
    # Execute the node
    case Graph.execute_node_by_id(node_id, context, actor_id) do
      {:ok, result} -> 
        {:ok, %{result: result}}
        
      {:error, :permission_denied} ->
        {:error, {-32003, "Permission denied", %{
          node_id: node_id,
          actor_id: actor_id
        }}}
        
      {:error, reason} -> 
        {:error, {-32000, "Execution failed", %{
          reason: inspect(reason)
        }}}
    end
  end

  @impl true
  def handle_tool_call(session_id, request_id, tool_name, arguments) when tool_name == "graph.query" do
    Logger.info("Handling graph.query tool call", 
      session_id: session_id, 
      request_id: request_id
    )
    
    # Extract query parameters
    query = arguments["query"] || %{}
    
    # Get the actor ID from the session
    {:ok, session_data} = MCP.Server.get_session_data(session_id)
    actor_id = Map.get(session_data, :actor_id, "default:user")
    
    # Execute the query
    case Graph.query(query, actor_id) do
      {:ok, results} -> 
        {:ok, %{results: results}}
        
      {:error, reason} -> 
        {:error, {-32000, "Query failed", %{
          reason: inspect(reason)
        }}}
    end
  end

  @impl true
  def handle_tool_call(session_id, request_id, tool_name, arguments) when tool_name == "graph.create_executable" do
    Logger.info("Handling graph.create_executable tool call", 
      session_id: session_id, 
      request_id: request_id
    )
    
    # Extract parameters
    node_id = arguments["id"]
    name = arguments["name"] || node_id
    executable_type = arguments["executable_type"]
    executable = arguments["executable"]
    metadata = arguments["metadata"] || %{}
    
    # Get the actor ID from the session
    {:ok, session_data} = MCP.Server.get_session_data(session_id)
    actor_id = Map.get(session_data, :actor_id, "default:user")
    
    # Create the node data
    node_data = Map.merge(metadata, %{
      name: name,
      executable_type: executable_type,
      executable: executable,
      created_by: actor_id,
      created_at: DateTime.utc_now()
    })
    
    # Create a transaction to add the node
    transaction = GraphOS.Graph.Transaction.new(GraphOS.Graph.Store.ETS)
    
    # Create the node
    node = GraphOS.Graph.Node.new(node_data, [id: node_id])
    
    # Add the node to the transaction
    transaction = GraphOS.Graph.Transaction.add(
      transaction,
      GraphOS.Graph.Operation.new(:create, :node, node, [id: node_id])
    )
    
    # Execute the transaction
    case Graph.execute(transaction, actor_id) do
      {:ok, _result} -> 
        # Grant the creator execute permission
        AccessControl.grant_permission(GraphOS.Graph, actor_id, node_id, [:execute])
        
        {:ok, %{node_id: node_id}}
        
      {:error, reason} -> 
        {:error, {-32000, "Failed to create executable node", %{
          reason: inspect(reason)
        }}}
    end
  end

  @impl true
  def handle_tool_call(session_id, request_id, tool_name, arguments) do
    # Pass through to parent implementation for any other tools
    super(session_id, request_id, tool_name, arguments)
  end

  # Private helper functions
  
  # Validate tool definition
  # This function is required by the MCP.Server behavior but is not exposed by the macro
  defp validate_tool(tool) do
    cond do
      not is_map(tool) ->
        {:error, "Tool must be a map"}
  
      not Map.has_key?(tool, "name") ->
        {:error, "Tool must have a name"}
  
      not Map.has_key?(tool, "description") ->
        {:error, "Tool must have a description"}
  
      true ->
        {:ok, tool}
    end
  end

  # Setup default permissions for new sessions
  defp setup_default_permissions(_session_id) do
    # Create a default user if it doesn't exist
    case AccessControl.define_actor(GraphOS.Graph, "default:user", %{
      name: "Default User", 
      type: "user",
      created_at: DateTime.utc_now()
    }) do
      {:ok, _} -> 
        # Grant some basic permissions to the default user
        AccessControl.grant_permission(GraphOS.Graph, "default:user", "graph:*", [:read])
        :ok
        
      {:error, _} -> 
        # User might already exist, that's fine
        :ok
    end
    
    # TODO: Consider setting up more granular permissions based on the session_id
  end
end