defmodule GraphOS.ComponentTest do
  use ExUnit.Case, async: true
  alias GraphOS.Component
  alias GraphOS.Component.Context

  defmodule TestComponent do
    use Component

    def call(context, opts) do
      Context.assign(context, :test_component, opts[:value])
    end
  end

  defmodule HaltingComponent do
    use Component

    def call(context, _opts) do
      Context.halt(context)
    end
  end

  defmodule CustomInitComponent do
    use Component

    @impl true
    def init(opts) do
      %{value: Keyword.get(opts, :value, :default) * 2}
    end

    @impl true
    def call(context, opts) do
      Context.assign(context, :custom_init, opts.value)
    end
  end

  describe "use Component" do
    test "defines a component with default init/1" do
      context = Context.new()
      result = TestComponent.init([value: 42])
      
      assert result == [value: 42]
      assert function_exported?(TestComponent, :call, 2)
    end
  end

  describe "execute/3" do
    test "executes a component with the given context and options" do
      context = Context.new()
      result = Component.execute(TestComponent, context, [value: 42])
      
      assert result.assigns.test_component == 42
    end
    
    test "calls the component's init function before call" do
      context = Context.new()
      result = Component.execute(CustomInitComponent, context, [value: 21])
      
      assert result.assigns.custom_init == 42
    end

    test "does not execute the component if the context is halted" do
      context = Context.new() |> Context.halt()
      result = Component.execute(TestComponent, context, [value: 42])
      
      refute Map.has_key?(result.assigns, :test_component)
      assert Context.halted?(result)
    end

    test "respects halting in the middle of execution" do
      context = Context.new()
      
      result = 
        context
        |> Component.execute(TestComponent, [value: 42])
        |> Component.execute(HaltingComponent, [])
        |> Component.execute(TestComponent, [value: 100])
      
      assert result.assigns.test_component == 42
      refute Map.has_key?(result.assigns, :second_test)
      assert Context.halted?(result)
    end
  end
end