defmodule GraphOS.Protocol.JSONRPC do
  @moduledoc """
  JSON-RPC 2.0 protocol adapter for GraphOS components.

  This adapter provides a JSON-RPC 2.0 interface to GraphOS components. It maps
  JSON-RPC methods to Graph operations and handles request batching, error
  standardization, and other protocol-specific behaviors.

  ## Configuration

  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:version` - JSON-RPC version to use (default: "2.0")
  - `:method_prefix` - Prefix for method names (default: "graph.")

  ## JSON-RPC Methods

  This adapter exposes Graph operations as JSON-RPC methods with the following format:

  - `graph.query.<path>` - Query operations (e.g., `graph.query.nodes.list`)
  - `graph.action.<path>` - Action operations (e.g., `graph.action.nodes.create`)
  - `graph.subscribe` - Subscribe to graph events
  - `graph.unsubscribe` - Unsubscribe from graph events

  ## Usage

  ```elixir
  # Start the adapter
  {:ok, pid} = GraphOS.Protocol.JSONRPC.start_link(
    name: MyJSONRPCAdapter,
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

  {:ok, response} = GraphOS.Protocol.JSONRPC.process(MyJSONRPCAdapter, request)
  # => {:ok, %{"jsonrpc" => "2.0", "id" => 1, "result" => [...]}}
  ```
  """

  use Boundary, deps: [:graph_os_core, :graph_os_graph]
  # Removed: use GraphOS.Protocol.Adapter
  use GenServer # Implement GenServer directly
  alias GraphOS.Adapter.Context # Keep Context if needed
  # Removed: alias GraphOS.Adapter.GenServer

  # JSON-RPC error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  # Custom error codes
  @unauthorized -32000
  @not_found -32001
  @validation_error -32002

  # State for this adapter
  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            graph_module: module(),
            # Removed: gen_server_adapter: pid(),
            version: String.t(),
            method_prefix: String.t()
          }

    defstruct [
      :graph_module,
      # Removed: :gen_server_adapter,
      :version,
      :method_prefix
    ]
  end

  @doc """
  Starts the JSONRPC adapter GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc """
  Processes a JSON-RPC request.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `request` - The JSON-RPC request (map or list of maps for batch requests)
    * `context` - Optional custom context for the request

  ## Returns

    * `{:ok, response}` - Successfully processed the request
    * `{:error, reason}` - Failed to process the request
  """
  @spec process(module() | pid(), map() | [map()], Context.t() | nil) ::
          {:ok, map() | [map()]} | {:error, term()}
  def process(adapter, request, context \\ nil) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter

    if adapter_pid && Process.alive?(adapter_pid) do
      # Create a new context if not provided
      context = context || Context.new()

      # Pass the request to the adapter as a GenServer call
      GenServer.call(adapter_pid, {:jsonrpc_request, request, context})
    else
      {:error, :adapter_not_found}
    end
  end

  # Adapter callbacks

  @impl true
  def init(opts) do
    graph_module = Keyword.get(opts, :graph_module, GraphOS.Graph)
    version = Keyword.get(opts, :version, "2.0")
    method_prefix = Keyword.get(opts, :method_prefix, "graph.")

    # TODO: Revisit plug handling if needed during request processing
    # plugs =
    #   case Keyword.get(opts, :auth, true) do
    #     false ->
    #       Keyword.get(opts, :plugs, [])
    #
    #     _ ->
    #       auth_plug = GraphOS.Protocol.Auth.Plug
    #       existing_plugs = Keyword.get(opts, :plugs, [])
    #
    #       # Only add the auth plug if it's not already included
    #       if Enum.any?(existing_plugs, fn
    #            ^auth_plug -> true
    #            {^auth_plug, _} -> true
    #            _ -> false
    #          end) do
    #         existing_plugs
    #       else
    #         [auth_plug | existing_plugs]
    #       end
    #   end

    # Removed internal GenServer adapter start
    # This GenServer (GraphOS.Protocol.JSONRPC) handles requests directly.
    state = %State{
      graph_module: graph_module,
      version: version,
      method_prefix: method_prefix
      # TODO: Store plugs if they need to be applied within handle_call/handle_cast
    }
    {:ok, state}
  end

  # TODO: Refactor handle_operation - it's likely not needed if using handle_call/handle_cast
  # @impl true
  # def handle_operation(operation, context, state) do
  #   # Delegate to the GenServer adapter
  #   # case GenServer.execute(state.gen_server_adapter, operation, context) do
  #   #   {:ok, result} ->
  #   #     # Operation succeeded
  #   #     {:reply, result, context, state}
  #   #
  #   #   {:error, reason} ->
  #   #     # Operation failed
  #   #     {:error, reason, context, state}
  #   # end
  #   {:error, :not_implemented} # Placeholder return
  # end

  @doc """

      {:error, reason} ->
        # Operation failed
        {:error, reason, context, state}
    end
  end

  @doc """
  Handles a JSON-RPC request.

  This function processes JSON-RPC requests and maps them to Graph operations.

  ## Parameters

    * `request` - The JSON-RPC request (map or list of maps for batch requests)
    * `context` - The request context
    * `state` - The adapter state

  ## Returns

    * `{:reply, response, context, state}` - Reply with result and updated context/state
    * `{:noreply, context, state}` - No immediate reply (for notifications)
    * `{:error, reason, context, state}` - Request failed with the given reason
  """
  @spec handle_jsonrpc_request(map() | [map()], Context.t(), State.t()) ::
          {:reply, map() | [map()], Context.t(), State.t()}
          | {:noreply, Context.t(), State.t()}
          | {:error, term(), Context.t(), State.t()}
  def handle_jsonrpc_request(request, context, state) when is_map(request) do
    # Process a single JSON-RPC request
    jsonrpc_version = Map.get(request, "jsonrpc", state.version)
    method = Map.get(request, "method")
    id = Map.get(request, "id")
    params = Map.get(request, "params", %{})

    # Create response skeleton
    response = %{
      "jsonrpc" => jsonrpc_version
    }

    # Add the id if present (for requests, not notifications)
    response = if id, do: Map.put(response, "id", id), else: response

    # Process the request
    result = process_jsonrpc_method(method, params, context, state)

    case result do
      {:ok, result_data, updated_context, updated_state} ->
        # For notifications (no id), don't include a response
        if id do
          {:reply, Map.put(response, "result", result_data), updated_context, updated_state}
        else
          {:noreply, updated_context, updated_state}
        end

      {:error, reason, updated_context, updated_state} ->
        # Convert the error to a JSON-RPC error object
        error = jsonrpc_error_from_reason(reason)

        # For notifications (no id), don't include a response
        if id do
          {:reply, Map.put(response, "error", error), updated_context, updated_state}
        else
          {:noreply, updated_context, updated_state}
        end
    end
  end

  def handle_jsonrpc_request(requests, context, state) when is_list(requests) do
    # Process a batch of JSON-RPC requests
    # This is a simplified implementation that processes them sequentially
    # A more optimized implementation would process them in parallel

    {responses, final_context, final_state} =
      Enum.reduce(requests, {[], context, state}, fn request,
                                                     {acc_responses, acc_context, acc_state} ->
        case handle_jsonrpc_request(request, acc_context, acc_state) do
          {:reply, response, updated_context, updated_state} ->
            {[response | acc_responses], updated_context, updated_state}

          {:noreply, updated_context, updated_state} ->
            {acc_responses, updated_context, updated_state}

          {:error, _reason, updated_context, updated_state} ->
            # Errors are already converted to JSON-RPC error objects in handle_jsonrpc_request/3
            {acc_responses, updated_context, updated_state}
        end
      end)

    # Return responses in the correct order (newest first from reduce)
    {:reply, Enum.reverse(responses), final_context, final_state}
  end

  # Additional GenServer callbacks for JSON-RPC requests

  @doc false
  def handle_call({:jsonrpc_request, request, context}, _from, %State{} = state) do
    # Check if the request is a notification (no ID)
    is_notification = is_map(request) && Map.get(request, "id") == nil

    # Handle the request
    case handle_jsonrpc_request(request, context, state) do
      {:reply, response, _updated_context, updated_state} ->
        # Return the response
        {:reply, {:ok, response}, updated_state}

      {:noreply, _updated_context, updated_state} ->
        # For notifications, return :ok
        if is_notification do
          {:reply, :ok, updated_state}
        else
          # This should not happen for non-notifications
          {:reply, {:error, :invalid_request}, updated_state}
        end

      {:error, reason, _updated_context, updated_state} ->
        # Return the error
        {:reply, {:error, reason}, updated_state}
    end
  end

  # Process a JSON-RPC method
  defp process_jsonrpc_method(nil, _params, context, state) do
    # Missing method
    error = %{
      "code" => @method_not_found,
      "message" => "Method not found: nil"
    }

    {:error, error, context, state}
  end

  defp process_jsonrpc_method(method, params, context, state) do
    prefix = state.method_prefix

    cond do
      String.starts_with?(method, "#{prefix}query.") ->
        # Query operation
        path = String.replace_prefix(method, "#{prefix}query.", "")

        # TODO: Dispatch to GraphOS.Conn instead of non-existent GenServer.execute
        # Need to get conn_pid from context or state
        # result_from_conn = GenServer.call(conn_pid, {:query, path, params})
        result = {:error, :not_implemented} # Placeholder

        case result do # Simulate handling result_from_conn
          {:ok, result_data} ->
            {:ok, result_data, context, state}

          {:error, reason} ->
            {:error, reason, context, state}
        end

      String.starts_with?(method, "#{prefix}action.") ->
        # Action operation
        path = String.replace_prefix(method, "#{prefix}action.", "")

        # TODO: Dispatch to GraphOS.Conn instead of non-existent GenServer.execute
        # Need to get conn_pid from context or state
        # result_from_conn = GenServer.call(conn_pid, {:action, path, params})
        result = {:error, :not_implemented} # Placeholder

        case result do # Simulate handling result_from_conn
          {:ok, result_data} ->
            {:ok, result_data, context, state}

          {:error, reason} ->
            {:error, reason, context, state}
        end

      method == "#{prefix}subscribe" ->
        # Subscribe to events
        case Map.fetch(params, "event") do
          {:ok, event_type} ->
            # TODO: Dispatch subscribe to GraphOS.Conn
            # Need conn_pid from context/state
            # result_from_conn = GenServer.call(conn_pid, {:subscribe, event_type, params}) # Assuming params might contain options
            result = {:error, :not_implemented} # Placeholder

            case result do # Simulate handling result_from_conn
              {:ok, _sub_id} -> # Assuming Conn returns subscription ID
                {:ok, %{"subscribed" => event_type}, context, state}

              {:error, reason} ->
                {:error, reason, context, state}
            end

          :error ->
            error = %{
              "code" => @invalid_params,
              "message" => "Missing required parameter: event"
            }

            {:error, error, context, state}
        end

      method == "#{prefix}unsubscribe" ->
        # Unsubscribe from events
        case Map.fetch(params, "event") do
          # TODO: Unsubscribe likely needs a subscription ID, not just event_type
          {:ok, _event_type_or_sub_id} ->
            # TODO: Dispatch unsubscribe to GraphOS.Conn
            # Need conn_pid and subscription_id
            # result_from_conn = GenServer.call(conn_pid, {:unsubscribe, sub_id})
            result = {:error, :not_implemented} # Placeholder

            case result do # Simulate handling result_from_conn
              :ok ->
                # TODO: Need to know what was actually unsubscribed if using event_type
                {:ok, %{"unsubscribed" => "unknown"}, context, state}

              {:error, reason} ->
                {:error, reason, context, state}
            end

          :error ->
            error = %{
              "code" => @invalid_params,
              "message" => "Missing required parameter: event"
            }

            {:error, error, context, state}
        end

      true ->
        # Unknown method
        error = %{
          "code" => @method_not_found,
          "message" => "Method not found: #{method}"
        }

        {:error, error, context, state}
    end
  end

  # Convert error reasons to JSON-RPC error objects
  defp jsonrpc_error_from_reason(reason) when is_map(reason) do
    # Already a JSON-RPC error object
    reason
  end

  defp jsonrpc_error_from_reason(reason) do
    {code, message, data} =
      case reason do
        {:internal_error, error} ->
          {@internal_error, "Internal error", %{"details" => inspect(error)}}

        {:validation_error, details} ->
          {@validation_error, "Validation error", %{"details" => details}}

        {:not_found, what} ->
          {@not_found, "Not found: #{what}", nil}

        {:unauthorized, _} ->
          {@unauthorized, "Unauthorized", nil}

        {:missing_param, param} ->
          {@invalid_params, "Missing required parameter: #{param}", nil}

        {:unknown_path, path} ->
          {@method_not_found, "Unknown path: #{path}", nil}

        _ ->
          {@internal_error, "Unexpected error", %{"details" => inspect(reason)}}
      end

    error = %{"code" => code, "message" => message}

    if data do
      Map.put(error, "data", data)
    else
      error
    end
  end

  # TODO: Review if terminate needs specific cleanup
  @impl true
  def terminate(_reason, _state) do
    # Terminate the GenServer adapter - No longer needed
    # if Process.alive?(adapter_pid) do
    #   GenServer.stop(adapter_pid, reason)
    # end
    :ok
  end
end
