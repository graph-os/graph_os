defmodule GraphOS.Dev.MCP.CodeGraphServer do
  @moduledoc """
  MCP Server implementation that integrates CodeGraph functionality.

  This module extends the standard MCP.Server with CodeGraph operations,
  allowing MCP clients to access CodeGraph functionality through the MCP protocol.
  """

  use MCP.Server
  alias GraphOS.Dev.CodeGraph
  require Logger

  @impl true
  def start(session_id) do
    # Call the parent's start method
    super(session_id)

    # Initialize CodeGraph if needed
    ensure_code_graph_initialized()

    :ok
  end

  @impl true
  def handle_list_tools(session_id, request_id, params) do
    # Get the base tools from the parent
    {:ok, base_result} = super(session_id, request_id, params)

    # Add the CodeGraph tools
    code_graph_tools = [
      %{
        name: "code_graph.build",
        description: "Build a code graph from the specified directory",
        inputSchema: %{
          type: "object",
          properties: %{
            directory: %{
              type: "string",
              description: "Directory to scan for code files"
            },
            recursive: %{
              type: "boolean",
              description: "Whether to recursively scan subdirectories"
            },
            file_pattern: %{
              type: "string",
              description: "Pattern for matching files"
            },
            exclude_pattern: %{
              type: "string",
              description: "Pattern for excluding files"
            }
          },
          required: ["directory"]
        },
        outputSchema: %{
          type: "object",
          properties: %{
            processed_files: %{
              type: "integer"
            },
            modules: %{
              type: "integer"
            },
            functions: %{
              type: "integer"
            },
            relationships: %{
              type: "integer"
            }
          }
        }
      },
      %{
        name: "code_graph.get_module_info",
        description: "Get information about a module from the code graph",
        inputSchema: %{
          type: "object",
          properties: %{
            module_name: %{
              type: "string",
              description: "Name of the module to get information about"
            }
          },
          required: ["module_name"]
        },
        outputSchema: %{
          type: "object",
          properties: %{
            module: %{
              type: "object"
            },
            functions: %{
              type: "array"
            },
            dependencies: %{
              type: "array"
            }
          }
        }
      },
      %{
        name: "code_graph.find_implementations",
        description: "Find implementations of a protocol or behaviour",
        inputSchema: %{
          type: "object",
          properties: %{
            protocol_or_behaviour: %{
              type: "string",
              description: "Name of the protocol or behaviour to find implementations for"
            }
          },
          required: ["protocol_or_behaviour"]
        },
        outputSchema: %{
          type: "object",
          properties: %{
            implementations: %{
              type: "array",
              items: %{
                type: "string"
              }
            }
          }
        }
      },
      %{
        name: "code_graph.query",
        description: "Query the code graph for relationships",
        inputSchema: %{
          type: "object",
          properties: %{
            query: %{
              type: "object",
              description: "Query parameters"
            }
          },
          required: ["query"]
        },
        outputSchema: %{
          type: "object",
          properties: %{
            results: %{
              type: "array"
            }
          }
        }
      }
    ]

    # Merge the tools lists
    updated_tools = Map.update!(base_result, :tools, fn tools -> tools ++ code_graph_tools end)

    {:ok, updated_tools}
  end

  @impl true
  def handle_tool_call(session_id, request_id, %{"name" => "code_graph.build"} = params, _meta) do
    Logger.info("Handling code_graph.build", session_id: session_id, request_id: request_id)

    tool_params = params["parameters"] || %{}
    directory = tool_params["directory"]

    if directory do
      opts = [
        recursive: Map.get(tool_params, "recursive", true),
        file_pattern: Map.get(tool_params, "file_pattern", "**/*.ex"),
        exclude_pattern: Map.get(tool_params, "exclude_pattern")
      ]

      case CodeGraph.build_graph(directory, opts) do
        {:ok, stats} ->
          {:ok, %{result: stats}}

        {:error, reason} ->
          {:error, {-32000, "Failed to build graph", %{message: inspect(reason)}}}
      end
    else
      {:error, {-32602, "Missing required parameter: directory", nil}}
    end
  end

  @impl true
  def handle_tool_call(
        session_id,
        request_id,
        %{"name" => "code_graph.get_module_info"} = params,
        _meta
      ) do
    Logger.info("Handling code_graph.get_module_info",
      session_id: session_id,
      request_id: request_id
    )

    tool_params = params["parameters"] || %{}
    module_name = tool_params["module_name"]

    if module_name do
      case CodeGraph.get_module_info(module_name) do
        {:ok, info} ->
          {:ok, %{result: info}}

        {:error, reason} ->
          {:error, {-32000, "Failed to get module info", %{message: inspect(reason)}}}
      end
    else
      {:error, {-32602, "Missing required parameter: module_name", nil}}
    end
  end

  @impl true
  def handle_tool_call(
        session_id,
        request_id,
        %{"name" => "code_graph.find_implementations"} = params,
        _meta
      ) do
    Logger.info("Handling code_graph.find_implementations",
      session_id: session_id,
      request_id: request_id
    )

    tool_params = params["parameters"] || %{}
    protocol_or_behaviour = tool_params["protocol_or_behaviour"]

    if protocol_or_behaviour do
      case CodeGraph.find_implementations(protocol_or_behaviour) do
        {:ok, implementations} ->
          {:ok, %{result: %{implementations: implementations}}}

        {:error, reason} ->
          {:error, {-32000, "Failed to find implementations", %{message: inspect(reason)}}}
      end
    else
      {:error, {-32602, "Missing required parameter: protocol_or_behaviour", nil}}
    end
  end

  @impl true
  def handle_tool_call(session_id, request_id, %{"name" => "code_graph.query"} = params, _meta) do
    Logger.info("Handling code_graph.query", session_id: session_id, request_id: request_id)

    tool_params = params["parameters"] || %{}
    query = tool_params["query"]

    if query do
      case apply_query(query) do
        {:ok, results} -> {:ok, %{result: %{results: results}}}
        {:error, reason} -> {:error, {-32000, "Query failed", %{message: inspect(reason)}}}
      end
    else
      {:error, {-32602, "Missing required parameter: query", nil}}
    end
  end

  @impl true
  def handle_tool_call(session_id, request_id, params, meta) do
    # Pass through to the parent's implementation
    super(session_id, request_id, params, meta)
  end

  # Required for MCP.Server behavior
  def validate_tool(tool) do
    MCP.Server.validate_tool(tool)
  end

  # Private helper methods

  # Helper function to ensure CodeGraph is initialized
  defp ensure_code_graph_initialized do
    # We'll use a simple approach - try to init but allow it to fail if already initialized
    Task.start(fn ->
      case CodeGraph.init() do
        :ok -> Logger.info("CodeGraph initialized successfully")
        {:error, {:already_started, _}} -> Logger.info("CodeGraph already initialized")
        {:error, reason} -> Logger.error("Failed to initialize CodeGraph: #{inspect(reason)}")
      end
    end)
  end

  # Helper function to apply different types of queries based on parameters
  defp apply_query(%{"type" => "dependencies", "module" => module_name}) do
    # Query for module dependencies
    case CodeGraph.get_module_info(module_name) do
      {:ok, %{dependencies: deps}} -> {:ok, deps}
      other -> other
    end
  end

  defp apply_query(%{"type" => "usages", "module" => _module_name}) do
    # Query for module usages (reverse dependencies)
    # Implementation depends on actual CodeGraph capabilities
    # This is a placeholder for the actual implementation
    {:error, "Not implemented yet"}
  end

  defp apply_query(params) do
    {:error, "Unsupported query type: #{inspect(params)}"}
  end
end
