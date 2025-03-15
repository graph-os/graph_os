defmodule GraphOS.Graph.Plug do
  @moduledoc """
  A behavior and utility functions for adapter middleware.
  
  IMPORTANT: This module is deprecated and will be removed in a future version.
  Please use `GraphOS.Adapter.PlugAdapter` instead.
  
  Plugs are composable middleware components that process operations as they
  flow through an adapter. They can modify the context, perform validation,
  add authentication/authorization, logging, error handling, etc.
  """
  
  require Logger
  
  @doc """
  Initializes the plug options.
  
  This function is deprecated. Please use `GraphOS.Adapter.PlugAdapter.init/1` instead.
  """
  @callback init(opts :: term) :: term
  
  @doc """
  Processes the context through the plug.
  
  This function is deprecated. Please use `GraphOS.Adapter.PlugAdapter.call/3` instead.
  """
  @callback call(context :: any(), next :: (any() -> any()), opts :: term) :: any()
  
  @doc """
  Builds a plug pipeline from a list of plugs.
  
  This function is deprecated. Please use `GraphOS.Adapter.PlugAdapter.build_pipeline/2` instead.
  """
  @spec build_pipeline(plugs :: list(), adapter :: module()) :: (any() -> any())
  def build_pipeline(plugs, adapter) do
    Logger.warning("GraphOS.Graph.Plug is deprecated")
    
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
          if context.halted do
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
  
  This function is deprecated. Please use `GraphOS.Adapter.PlugAdapter.prepare_plug/1` instead.
  """
  @spec prepare_plug(plug :: module() | {module(), term()}) :: {module(), term()}
  def prepare_plug(plug) do
    Logger.warning("GraphOS.Graph.Plug is deprecated")
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
      require Logger
      Logger.warning("GraphOS.Graph.Plug is deprecated")
      
      @behaviour GraphOS.Graph.Plug
      
      @impl true
      def init(opts), do: opts
      
      defoverridable init: 1
    end
  end
end