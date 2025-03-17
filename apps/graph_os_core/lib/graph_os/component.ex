defmodule GraphOS.Component do
  @moduledoc """
  Defines the behavior for GraphOS components.

  Components are the building blocks of GraphOS pipelines, similar to how
  Plugs work in the Phoenix/Plug ecosystem. Each component receives a context,
  performs an operation, and returns a potentially modified context.

  Components can be composed together to form complex processing pipelines
  while maintaining separation of concerns and modularity.

  ## Defining a Component

  To create a component, define a module that implements the `GraphOS.Component`
  behavior, or use the `use GraphOS.Component` macro which provides default
  implementations:

  ```elixir
  defmodule MyComponent do
    use GraphOS.Component
    
    @impl true
    def init(opts) do
      # Process options at compile time
      %{param: Keyword.get(opts, :param, :default)}
    end
    
    @impl true
    def call(context, opts) do
      # Perform component logic
      GraphOS.Component.Context.assign(context, :value, opts.param)
    end
  end
  ```

  ## Component Pipeline

  Components can be composed into pipelines:

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

  alias GraphOS.Component.Context

  @doc """
  Initializes the component options.

  This function is called at compile time when the component is being prepared
  for use in a pipeline. It can be used to validate and preprocess options.

  ## Parameters

    * `opts` - The options passed to the component when it is included in a pipeline
    
  ## Returns

    * The processed options that will be passed to `call/2`
  """
  @callback init(opts :: term) :: term

  @doc """
  Processes the context through the component.

  This function performs the main logic of the component. It receives a context
  and should return a modified context.

  ## Parameters

    * `context` - The current context being processed
    * `opts` - The options returned by `init/1`
    
  ## Returns

    * A modified context
  """
  @callback call(context :: Context.t(), opts :: term) :: Context.t()

  @doc """
  Executes a component with the given context and options.

  This function handles the normal execution flow of a component, including
  initialization of options and skipping execution if the context is halted.

  Can be called in two ways:
  - execute(component, context, opts)
  - execute(context, component, opts) - pipeline friendly version

  ## Parameters for standard version

    * `component` - The component module to execute
    * `context` - The current context
    * `opts` - Options to pass to the component's init function
    
  ## Parameters for pipeline-friendly version

    * `context` - The current context
    * `component` - The component module to execute
    * `opts` - Options to pass to the component's init function
    
  ## Returns

    * A modified context
  """
  @spec execute(module | Context.t(), Context.t() | module, term) :: Context.t()
  def execute(first_arg, second_arg, opts \\ [])

  def execute(component, %Context{} = context, opts) when is_atom(component) do
    if Context.halted?(context) do
      context
    else
      prepared_opts = component.init(opts)
      component.call(context, prepared_opts)
    end
  end

  def execute(%Context{} = context, component, opts) when is_atom(component) do
    execute(component, context, opts)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour GraphOS.Component

      @impl true
      def init(opts), do: opts

      defoverridable init: 1
    end
  end
end
