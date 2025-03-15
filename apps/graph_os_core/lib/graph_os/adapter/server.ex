defmodule GraphOS.Adapter.Server do
  @moduledoc """
  GenServer implementation for GraphOS Graph adapters.
  
  This server manages the lifecycle of adapters and handles incoming operations.
  It applies the plug pipeline to each operation context before passing it to
  the adapter's implementation.
  """
  
  use GenServer
  require Logger
  
  alias GraphOS.Adapter.GraphAdapter
  alias GraphOS.Adapter.Context
  alias GraphOS.Adapter.PlugAdapter
  
  # Server state
  defmodule State do
    @moduledoc false
    
    @type t :: %__MODULE__{
      adapter_module: module(),
      adapter_state: term(),
      pipeline: (Context.t() -> Context.t())
    }
    
    defstruct [
      :adapter_module,
      :adapter_state,
      :pipeline
    ]
  end
  
  # Client API
  
  @doc """
  Starts the adapter server.
  
  ## Parameters
  
    * `init_arg` - A tuple containing the adapter module and options
    * `server_opts` - GenServer options
    
  ## Returns
  
    * `{:ok, pid}` - Successfully started the server
    * `{:error, reason}` - Failed to start the server
  """
  @spec start_link({module(), keyword()}, GenServer.options()) :: GenServer.on_start()
  def start_link({adapter_module, opts}, server_opts \\ []) do
    GenServer.start_link(__MODULE__, {adapter_module, opts}, server_opts)
  end
  
  # Server callbacks
  
  @impl true
  def init({adapter_module, opts}) do
    Logger.debug("Starting GraphOS.Adapter.Server with #{inspect(adapter_module)}")
    
    # Extract plugs from options and build the pipeline
    plugs = Keyword.get(opts, :plugs, [])
    pipeline = PlugAdapter.build_pipeline(plugs, adapter_module)
    
    # Initialize the adapter
    case adapter_module.init(opts) do
      {:ok, adapter_state} ->
        state = %State{
          adapter_module: adapter_module,
          adapter_state: adapter_state,
          pipeline: pipeline
        }
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to initialize adapter #{inspect(adapter_module)}: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:jsonrpc_request, request, context}, from, %State{} = state) do
    # Delegate to the adapter's handle_jsonrpc_request if it exists
    if function_exported?(state.adapter_module, :handle_jsonrpc_request, 3) do
      case state.adapter_module.handle_jsonrpc_request(request, context, state.adapter_state) do
        {:reply, result, updated_context, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, {:ok, result}, new_state}
          
        {:noreply, _updated_context, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, :ok, new_state}
          
        {:error, reason, _updated_context, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, {:error, reason}, new_state}
      end
    else
      # If the adapter doesn't handle JSONRPC, return an error
      {:reply, {:error, :not_supported}, state}
    end
  end
  
  @impl true
  def handle_call({:subscribe, pid, event_type}, _from, %State{} = state) do
    # Delegate to the adapter's handle_subscribe if it exists
    if function_exported?(state.adapter_module, :handle_subscribe, 4) do
      case state.adapter_module.handle_subscribe(pid, event_type, state.adapter_state) do
        {:ok, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, :ok, new_state}
          
        {:error, reason, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, {:error, reason}, new_state}
      end
    else
      # If the adapter doesn't handle subscriptions, return an error
      {:reply, {:error, :not_supported}, state}
    end
  end
  
  @impl true
  def handle_call({:unsubscribe, pid, event_type}, _from, %State{} = state) do
    # Delegate to the adapter's handle_unsubscribe if it exists
    if function_exported?(state.adapter_module, :handle_unsubscribe, 4) do
      case state.adapter_module.handle_unsubscribe(pid, event_type, state.adapter_state) do
        {:ok, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, :ok, new_state}
          
        {:error, reason, updated_adapter_state} ->
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, {:error, reason}, new_state}
      end
    else
      # If the adapter doesn't handle unsubscriptions, return an error
      {:reply, {:error, :not_supported}, state}
    end
  end
  
  @impl true
  def handle_call({:operation, operation, context}, _from, %State{} = state) do
    # Add the adapter module to the context if not already present
    context = if context.adapter, do: context, else: %{context | adapter: state.adapter_module}
    
    # Check the operation type and ensure the path is set
    {_operation_type, path, _params} = case operation do
      {:query, path, params} -> {:query, path, params}
      {:action, path, params} -> {:action, path, params}
    end
    
    # Ensure the path is set in the context
    context = if context.path, do: context, else: %{context | path: path}
    
    # Apply the plug pipeline to the context
    # This doesn't actually execute the operation yet
    context_with_plugs = state.pipeline.(context)
    
    if Context.halted?(context_with_plugs) do
      # If the context was halted by a plug, return the error
      error = Context.error(context_with_plugs) || {:unknown_error, "Operation halted with no error specified"}
      {:reply, {:error, error}, state}
    else
      # Execute the operation in the adapter
      case state.adapter_module.handle_operation(operation, context_with_plugs, state.adapter_state) do
        {:reply, result, updated_context, updated_adapter_state} ->
          # Operation succeeded with a result
          new_state = %{state | adapter_state: updated_adapter_state}
          
          if Context.error?(updated_context) do
            # The adapter encountered an error
            {:reply, {:error, Context.error(updated_context)}, new_state}
          else
            # Return the successful result
            {:reply, {:ok, result}, new_state}
          end
          
        {:noreply, _updated_context, updated_adapter_state} ->
          # Operation was processed asynchronously
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, :ok, new_state}
          
        {:error, reason, _updated_context, updated_adapter_state} ->
          # Operation failed with an error
          new_state = %{state | adapter_state: updated_adapter_state}
          {:reply, {:error, reason}, new_state}
      end
    end
  end
  
  @impl true
  def handle_cast({:publish, event_type, event_data}, %State{} = state) do
    # Delegate to the adapter's handle_publish if it exists
    if function_exported?(state.adapter_module, :handle_publish, 4) do
      case state.adapter_module.handle_publish(event_type, event_data, state.adapter_state) do
        {:ok, updated_adapter_state} ->
          {:noreply, %{state | adapter_state: updated_adapter_state}}
          
        {:error, _reason, updated_adapter_state} ->
          # Log error but continue processing
          {:noreply, %{state | adapter_state: updated_adapter_state}}
      end
    else
      # If the adapter doesn't handle publishing, just continue
      {:noreply, state}
    end
  end
  
  @impl true
  def terminate(reason, %State{adapter_module: adapter_module, adapter_state: adapter_state}) do
    Logger.debug("Terminating GraphOS.Adapter.Server with reason: #{inspect(reason)}")
    
    # Call the adapter's terminate callback if it exists
    if function_exported?(adapter_module, :terminate, 2) do
      adapter_module.terminate(reason, adapter_state)
    end
    
    :ok
  end
end