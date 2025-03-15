defmodule GraphOS.Graph.Adapters.JSONRPC do
  @deprecated "Use GraphOS.Adapter.JSONRPC instead"
  @moduledoc """
  A Graph adapter for JSON-RPC 2.0 protocol integration.

  This adapter builds on top of the GenServer adapter to provide JSON-RPC 2.0
  protocol support. It maps JSON-RPC methods to Graph operations and handles
  request batching, error standardization, etc.

  ## Configuration

  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:gen_server_adapter` - The GenServer adapter to use (default: `GraphOS.Graph.Adapters.GenServer`)
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
  {:ok, pid} = GraphOS.Graph.Adapter.start_link(
    adapter: GraphOS.Graph.Adapters.JSONRPC,
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

  {:ok, response} = GraphOS.Graph.Adapters.JSONRPC.process(MyJSONRPCAdapter, request)
  # => {:ok, %{"jsonrpc" => "2.0", "id" => 1, "result" => [...]}}
  ```
  """

  # Previously: use GraphOS.Graph.Adapter
  require Logger

  alias GraphOS.Graph.Adapter.Context
  alias GraphOS.Graph.Adapters.GenServer, as: GenServerAdapter

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
      gen_server_adapter: pid(),
      version: String.t(),
      method_prefix: String.t()
    }

    defstruct [
      :graph_module,
      :gen_server_adapter,
      :version,
      :method_prefix
    ]
  end

  # Client API

  @doc """
  Starts the JSONRPC adapter as a linked process.

  ## Parameters

    * `opts` - Adapter configuration options

  ## Returns

    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    GraphOS.Graph.Adapter.start_link(Keyword.put(opts, :adapter, __MODULE__))
  end

  @doc """
  Processes a JSON-RPC request.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `request` - The JSON-RPC request
    * `context` - Optional custom context for the operation

  ## Returns

    * `{:ok, response}` - Successfully processed the request
    * `{:error, reason}` - Failed to process the request
  """
  @spec process(module() | pid(), map() | list(map()), Context.t() | nil) ::
          {:ok, map() | list(map())} | {:error, term()}
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

    # Start the GenServer adapter as a child
    gen_server_opts = Keyword.merge(opts, [
      adapter: Keyword.get(opts, :gen_server_adapter, GenServerAdapter),
      graph_module: graph_module
    ])

    case GenServerAdapter.start_link(gen_server_opts) do
      {:ok, gen_server_pid} ->
        state = %State{
          graph_module: graph_module,
          gen_server_adapter: gen_server_pid,
          version: version,
          method_prefix: method_prefix
        }
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles a JSON-RPC request.

  This function is called by the adapter server to process a JSON-RPC request.
  It validates the request format, extracts the operation, and delegates to the
  appropriate handler.

  ## Parameters

    * `request` - The JSON-RPC request
    * `context` - The current context
    * `state` - The current adapter state

  ## Returns

    * `{:reply, response, context, state}` - Reply with a result and updated context/state
    * `{:noreply, context, state}` - No immediate reply (for async operations)
    * `{:error, reason, context, state}` - Operation failed with the given reason
  """
  @spec handle_jsonrpc_request(map() | list(map()), Context.t(), State.t()) ::
          {:reply, map() | list(map()), Context.t(), State.t()} |
          {:noreply, Context.t(), State.t()} |
          {:error, term(), Context.t(), State.t()}
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

      {error_obj, :error, updated_context} when is_map(error_obj) ->
        # Already a JSON-RPC error object

        # For notifications (no id), don't include a response
        if id do
          {:reply, Map.put(response, "error", error_obj), updated_context, state}
        else
          {:noreply, updated_context, state}
        end

      {result_obj, :success, updated_context} ->
        # Success with result

        # For notifications (no id), don't include a response
        if id do
          {:reply, Map.put(response, "result", result_obj), updated_context, state}
        else
          {:noreply, updated_context, state}
        end
    end
  end

  def handle_jsonrpc_request(requests, context, state) when is_list(requests) do
    # Process a batch of JSON-RPC requests
    # This is a simplified implementation that processes them sequentially
    # A more optimized implementation would process them in parallel

    {responses, final_context, final_state} =
      Enum.reduce(requests, {[], context, state}, fn request, {acc_responses, acc_context, acc_state} ->
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

  @impl true
  def handle_operation({:query, path, params}, context, state) do
    # Delegate to the GenServer adapter
    case GenServerAdapter.execute(state.gen_server_adapter, {:query, path, params}, context) do
      {:ok, result} ->
        # Query succeeded
        {:reply, result, context, state}

      {:error, reason} ->
        # Query failed
        {:error, reason, context, state}
    end
  end

  @impl true
  def handle_operation({:action, path, params}, context, state) do
    # Delegate to the GenServer adapter
    case GenServerAdapter.execute(state.gen_server_adapter, {:action, path, params}, context) do
      {:ok, result} ->
        # Action succeeded
        {:reply, result, context, state}

      {:error, reason} ->
        # Action failed
        {:error, reason, context, state}
    end
  end

  # Additional GenServer callbacks for JSON-RPC requests

  @doc false
  def handle_call({:jsonrpc_request, request, context}, _from, %State{} = state) do
    # This function is deprecated and is here for backwards compatibility
    # We now use handle_jsonrpc_request/3 directly

    # Check if the request is a notification (no ID)
    is_notification = is_map(request) && Map.get(request, "id") == nil

    # Handle the request using our new interface
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

  # Private JSON-RPC processing functions

  # Process a JSON-RPC request (single or batch)
  defp process_jsonrpc_request(requests, context, state) when is_list(requests) do
    # Process batch requests in parallel
    responses = Enum.map(requests, fn request ->
      {response, _} = process_single_request(request, context, state)
      response
    end)

    {responses, context}
  end

  defp process_jsonrpc_request(request, context, state) do
    process_single_request(request, context, state)
  end

  # Process a single JSON-RPC request
  defp process_single_request(request, context, state) do
    # Validate that it's a valid JSON-RPC request
    case validate_jsonrpc_request(request, state.version) do
      :ok ->
        # Extract the request components
        request_id = Map.get(request, "id")
        method = Map.get(request, "method")
        params = Map.get(request, "params", %{})

        # Check if this is a notification (no ID)
        is_notification = request_id == nil

        # Process the method and get a result
        {result, status, updated_context} = process_jsonrpc_method(method, params, context, state)

        # Return the appropriate response
        response = case {is_notification, status} do
          {true, _} ->
            # Notifications don't return a response
            nil

          {false, :success} ->
            # Success response
            %{
              "jsonrpc" => state.version,
              "id" => request_id,
              "result" => result
            }

          {false, :error} ->
            # Error response
            %{
              "jsonrpc" => state.version,
              "id" => request_id,
              "error" => result
            }
        end

        {response, updated_context}

      {:error, error_code, error_message} ->
        # Invalid JSON-RPC request
        response = %{
          "jsonrpc" => state.version,
          "id" => nil,
          "error" => %{
            "code" => error_code,
            "message" => error_message
          }
        }

        {response, context}
    end
  end

  # Validate a JSON-RPC request
  defp validate_jsonrpc_request(request, version) do
    cond do
      not is_map(request) ->
        {:error, @invalid_request, "Request must be an object"}

      Map.get(request, "jsonrpc") != version ->
        {:error, @invalid_request, "Invalid JSON-RPC version"}

      not Map.has_key?(request, "method") ->
        {:error, @invalid_request, "Method is required"}

      not is_binary(Map.get(request, "method")) ->
        {:error, @invalid_request, "Method must be a string"}

      not (is_map(Map.get(request, "params", %{})) or is_list(Map.get(request, "params", []))) ->
        {:error, @invalid_params, "Params must be an object or array"}

      true ->
        :ok
    end
  end

  # Process a JSON-RPC method
  @doc false
  def process_jsonrpc_method(nil, _params, context, _state) do
    # Missing method
    {%{
      "code" => @method_not_found,
      "message" => "Method not found: nil"
    }, :error, context}
  end

  @doc false
  def process_jsonrpc_method(method, params, context, state) do
    prefix = state.method_prefix

    cond do
      String.starts_with?(method, "#{prefix}query.") ->
        # Query operation
        path = String.replace_prefix(method, "#{prefix}query.", "")

        case GenServerAdapter.execute(state.gen_server_adapter, {:query, path, params}, context) do
          {:ok, result} ->
            {result, :success, context}

          {:error, reason} ->
            {jsonrpc_error_from_reason(reason), :error, context}
        end

      String.starts_with?(method, "#{prefix}action.") ->
        # Action operation
        path = String.replace_prefix(method, "#{prefix}action.", "")

        case GenServerAdapter.execute(state.gen_server_adapter, {:action, path, params}, context) do
          {:ok, result} ->
            {result, :success, context}

          {:error, reason} ->
            {jsonrpc_error_from_reason(reason), :error, context}
        end

      method == "#{prefix}subscribe" ->
        # Subscribe to events
        case Map.fetch(params, "event") do
          {:ok, event_type} ->
            case GenServerAdapter.subscribe(state.gen_server_adapter, event_type) do
              :ok ->
                {%{"subscribed" => event_type}, :success, context}

              {:error, reason} ->
                {jsonrpc_error_from_reason(reason), :error, context}
            end

          :error ->
            {%{
              "code" => @invalid_params,
              "message" => "Missing required parameter: event"
            }, :error, context}
        end

      method == "#{prefix}unsubscribe" ->
        # Unsubscribe from events
        case Map.fetch(params, "event") do
          {:ok, event_type} ->
            case GenServerAdapter.unsubscribe(state.gen_server_adapter, event_type) do
              :ok ->
                {%{"unsubscribed" => event_type}, :success, context}

              {:error, reason} ->
                {jsonrpc_error_from_reason(reason), :error, context}
            end

          :error ->
            {%{
              "code" => @invalid_params,
              "message" => "Missing required parameter: event"
            }, :error, context}
        end

      true ->
        # Unknown method
        {%{
          "code" => @method_not_found,
          "message" => "Method not found: #{method}"
        }, :error, context}
    end
  end

  # Convert error reasons to JSON-RPC error objects
  @doc false
  def jsonrpc_error_from_reason(reason) do
    {code, message, data} = case reason do
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

  @impl true
  def terminate(reason, %State{gen_server_adapter: adapter_pid}) do
    # Terminate the GenServer adapter
    if Process.alive?(adapter_pid) do
      GenServer.stop(adapter_pid, reason)
    end

    :ok
  end
end
