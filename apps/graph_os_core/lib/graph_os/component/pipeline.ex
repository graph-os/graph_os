defmodule GraphOS.Component.Pipeline do
  @moduledoc """
  Provides functionality for creating and executing component pipelines.
  
  A pipeline is a sequence of components that process a context in order.
  Each component in the pipeline can modify the context before passing it
  to the next component. Processing stops if a component halts the context.
  
  ## Example
  
  ```elixir
  pipeline = [
    {AuthComponent, realm: "api"},
    ValidatorComponent,
    {HandlerComponent, repo: MyRepo}
  ]
  
  context = GraphOS.Component.Context.new(params: params)
  result = GraphOS.Component.Pipeline.run(context, pipeline)
  ```
  """

  alias GraphOS.Component
  alias GraphOS.Component.Context

  @doc """
  Runs a context through a pipeline of components.
  
  The pipeline is a list of components to execute in order. Each component
  can be specified as:
  
  * A module implementing the `GraphOS.Component` behavior
  * A tuple of `{module, opts}` where `module` implements the behavior and
    `opts` are options to pass to the component
  
  ## Parameters
  
    * `context` - The initial context to process
    * `pipeline` - A list of components to execute
    
  ## Returns
  
    * The resulting context after processing through the pipeline
  
  ## Example
  
  ```elixir
  context = Context.new(params: %{id: 123})
  
  result = Pipeline.run(context, [
    {AuthComponent, realm: "api"},
    ValidationComponent,
    {ProcessingComponent, mode: :sync}
  ])
  ```
  """
  @spec run(Context.t(), list()) :: Context.t()
  def run(%Context{} = context, pipeline) when is_list(pipeline) do
    pipeline
    |> normalize_pipeline()
    |> Enum.reduce(context, fn {component, opts}, acc ->
      Component.execute(component, acc, opts)
    end)
  end

  @doc """
  Builds a pipeline function that can be called with a context.
  
  This is useful when you want to define a pipeline once and reuse it
  multiple times without having to specify the components each time.
  
  ## Parameters
  
    * `pipeline` - A list of components to build into a pipeline
    
  ## Returns
  
    * A function that takes a context and returns the processed context
  
  ## Example
  
  ```elixir
  pipeline = Pipeline.build([
    {AuthComponent, realm: "api"},
    ValidationComponent
  ])
  
  # Later, use the pipeline:
  result = pipeline.(Context.new(params: params))
  ```
  """
  @spec build(list()) :: (Context.t() -> Context.t())
  def build(pipeline) when is_list(pipeline) do
    normalized = normalize_pipeline(pipeline)
    
    fn %Context{} = context ->
      Enum.reduce(normalized, context, fn {component, opts}, acc ->
        Component.execute(component, acc, opts)
      end)
    end
  end

  # Ensures that all pipeline entries are in {module, opts} format
  defp normalize_pipeline(pipeline) do
    Enum.map(pipeline, fn
      {component, opts} when is_atom(component) -> {component, opts}
      component when is_atom(component) -> {component, []}
      other -> raise ArgumentError, "Invalid pipeline entry: #{inspect(other)}"
    end)
  end
end