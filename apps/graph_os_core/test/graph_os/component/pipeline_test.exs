defmodule GraphOS.Component.PipelineTest do
  use ExUnit.Case, async: true
  alias GraphOS.Component
  alias GraphOS.Component.Context
  alias GraphOS.Component.Pipeline

  defmodule ComponentOne do
    use Component

    def call(context, opts) do
      value = Keyword.get(opts, :value, 1)

      context
      |> Context.assign(:component_one, true)
      |> Context.assign(:value, value)
    end
  end

  defmodule ComponentTwo do
    use Component

    def call(context, _opts) do
      current_value = Map.get(context.assigns, :value, 0)

      context
      |> Context.assign(:component_two, true)
      |> Context.assign(:value, current_value * 2)
    end
  end

  defmodule HaltingComponent do
    use Component

    def call(context, _opts) do
      context
      |> Context.assign(:halting_component, true)
      |> Context.halt()
    end
  end

  defmodule ErrorComponent do
    use Component

    def call(context, _opts) do
      Context.put_error(context, :test_error, "An error occurred")
    end
  end

  describe "run/2" do
    test "processes a context through a pipeline of components" do
      context = Context.new()

      result =
        Pipeline.run(context, [
          ComponentOne,
          ComponentTwo
        ])

      assert result.assigns.component_one == true
      assert result.assigns.component_two == true
      assert result.assigns.value == 2
    end

    test "accepts components with options" do
      context = Context.new()

      result =
        Pipeline.run(context, [
          {ComponentOne, value: 5},
          ComponentTwo
        ])

      assert result.assigns.value == 10
    end

    test "stops processing when a component halts the context" do
      context = Context.new()

      result =
        Pipeline.run(context, [
          ComponentOne,
          HaltingComponent,
          ComponentTwo
        ])

      assert result.assigns.component_one == true
      assert result.assigns.halting_component == true
      refute Map.has_key?(result.assigns, :component_two)
      assert Context.halted?(result)
    end

    test "stops processing when an error occurs and halts" do
      context = Context.new()

      result =
        Pipeline.run(context, [
          ComponentOne,
          ErrorComponent,
          ComponentTwo
        ])

      assert result.assigns.component_one == true
      assert Context.error?(result)
      assert Context.error(result) == {:test_error, "An error occurred"}
      refute Map.has_key?(result.assigns, :component_two)
      assert Context.halted?(result)
    end
  end

  describe "build/1" do
    test "creates a pipeline function that can be called with a context" do
      pipeline =
        Pipeline.build([
          {ComponentOne, value: 5},
          ComponentTwo
        ])

      context = Context.new()
      result = pipeline.(context)

      assert result.assigns.component_one == true
      assert result.assigns.component_two == true
      assert result.assigns.value == 10
    end
  end
end
