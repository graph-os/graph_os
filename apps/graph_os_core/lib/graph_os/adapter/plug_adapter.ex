defmodule GraphOS.Adapter.PlugAdapter do
  @moduledoc """
  A behavior and utility functions for adapter middleware.
  
  Plugs are composable middleware components that process operations as they
  flow through an adapter. They can modify the context, perform validation,
  add authentication/authorization, logging, error handling, etc.
  
  ## Defining a Plug
  
  To create a plug, define a module that implements the `GraphOS.Adapter.PlugAdapter`
  behavior, or use the `use GraphOS.Adapter.PlugAdapter` macro:
  
  ```elixir
  defmodule MyPlug do
    use GraphOS.Adapter.PlugAdapter
    
    @impl true
    def init(opts) do
      # Process options at compile time
      %{param: Keyword.get(opts, :param, :default)}
    end
    
    @impl true
    def call(context, next, opts) do
      # Perform plug logic before operation
      updated_context = add_some_values(context)
      
      # Call the next plug or adapter in the pipeline
      result_context = next.(updated_context)
      
      # Optionally modify the result context
      add_metrics(result_context)
    end
    
    defp add_some_values(context) do
      GraphOS.Adapter.Context.assign(context, :added_by_my_plug, true)
    end
    
    defp add_metrics(context) do
      GraphOS.Adapter.Context.put_metadata(context, :processed_at, DateTime.utc_now())
    end
  end
  ```
  
  ## Using Plugs in an Adapter
  
  Plugs are specified when starting an adapter:
  
  ```elixir
  GraphOS.Adapter.GraphAdapter.start_link(
    adapter: MyAdapter,
    plugs: [
      {AuthPlug, realm: "api"},
      LoggingPlug,
      ErrorHandlingPlug
    ]
  )
  ```
  """
  
  alias GraphOS.Adapter.Context
  
  @doc """
  Initializes the plug options.
  
  This callback is invoked at compile time when the plug is being prepared
  for use in a pipeline. It can be used to validate and preprocess options.
  
  ## Parameters
  
    * `opts` - The options passed to the plug when it is included in a pipeline
    
  ## Returns
  
    * The processed options that will be passed to `call/3`
  """
  @callback init(opts :: term) :: term
  
  @doc """
  Processes the context through the plug.
  
  This callback is invoked at runtime for each operation and receives the
  current context, a function to call the next plug in the pipeline,
  and the processed options from `init/1`.
  
  ## Parameters
  
    * `context` - The current operation context
    * `next` - A function that takes a context and continues the pipeline
    * `opts` - The options returned by `init/1`
    
  ## Returns
  
    * A modified context
  """
  @callback call(context :: Context.t(), next :: (Context.t() -> Context.t()), opts :: term) :: Context.t()
  
  @doc """
  Builds a plug pipeline from a list of plugs.
  
  This function processes a list of plugs, initializing their options and
  creating a function that will execute them in sequence.
  
  ## Parameters
  
    * `plugs` - A list of plugs, where each plug is a module or a {module, opts} tuple
    * `adapter` - The adapter module that will handle operations after all plugs
    
  ## Returns
  
    * A function that takes a context and executes the pipeline
  """
  @spec build_pipeline(plugs :: list(), adapter :: module()) :: (Context.t() -> Context.t())
  def build_pipeline(plugs, _adapter) do
    # Build the plugs pipeline with initialized options
    plugs_with_opts = Enum.map(plugs, &prepare_plug/1)
    
    # Create a function that will execute the pipeline
    fn context ->
      # The pipeline starts with the adapter's handle_operation function
      final_handler = fn context ->
        # The adapter is responsible for actually processing the operation
        # But we don't call it directly here since the plugs will eventually call it
        context
      end
      
      # Build the pipeline in reverse order so that the first plug is executed first
      pipeline = Enum.reduce(Enum.reverse(plugs_with_opts), final_handler, fn {plug, opts}, next ->
        fn context ->
          if Context.halted?(context) do
            # If the context is halted, skip this plug
            context
          else
            # Execute the plug and pass it the continuation
            plug.call(context, next, opts)
          end
        end
      end)
      
      # Execute the pipeline starting with the first plug
      pipeline.(context)
    end
  end
  
  @doc """
  Prepares a plug by extracting its module and initializing its options.
  
  ## Parameters
  
    * `plug` - A plug module or a {module, opts} tuple
    
  ## Returns
  
    * A {module, initialized_opts} tuple
  """
  @spec prepare_plug(plug :: module() | {module(), term()}) :: {module(), term()}
  def prepare_plug(plug) do
    case plug do
      {module, opts} when is_atom(module) ->
        {module, module.init(opts)}
      module when is_atom(module) ->
        {module, module.init([])}
    end
  end
  
  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour GraphOS.Adapter.PlugAdapter
      
      @impl true
      def init(opts), do: opts
      
      defoverridable init: 1
    end
  end
end