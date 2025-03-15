defmodule GraphOS.Component.ExampleTest do
  use ExUnit.Case, async: true
  alias GraphOS.Component
  alias GraphOS.Component.Context
  alias GraphOS.Component.Example

  describe "component interface" do
    test "modifies the context with init options" do
      context = Context.new()
      opts = Example.init(prefix: "TestPrefix")
      result = Example.call(context, opts)
      
      assert result.assigns.example_prefix == "TestPrefix"
      assert result.metadata.component == Example
    end
  end

  describe "math tool" do
    test "performs addition" do
      context = Context.new()
      params = %{operation: "add", a: 5, b: 3}
      
      result = Example.execute_tool(:math, context, params)
      
      refute Context.error?(result)
      assert result.result == %{result: 8}
    end

    test "performs subtraction" do
      context = Context.new()
      params = %{operation: "subtract", a: 10, b: 4}
      
      result = Example.execute_tool(:math, context, params)
      
      refute Context.error?(result)
      assert result.result == %{result: 6}
    end

    test "performs multiplication" do
      context = Context.new()
      params = %{operation: "multiply", a: 6, b: 7}
      
      result = Example.execute_tool(:math, context, params)
      
      refute Context.error?(result)
      assert result.result == %{result: 42}
    end

    test "performs division" do
      context = Context.new()
      params = %{operation: "divide", a: 20, b: 5}
      
      result = Example.execute_tool(:math, context, params)
      
      refute Context.error?(result)
      assert result.result == %{result: 4.0}
    end

    test "handles division by zero" do
      context = Context.new()
      params = %{operation: "divide", a: 10, b: 0}
      
      result = Example.execute_tool(:math, context, params)
      
      assert Context.error?(result)
      assert Context.error(result) == {:invalid_operation, "Division by zero"}
    end

    test "handles unknown operations" do
      context = Context.new()
      params = %{operation: "power", a: 2, b: 3}
      
      result = Example.execute_tool(:math, context, params)
      
      assert Context.error?(result)
      assert Context.error(result) == {:invalid_operation, "Unknown operation: power"}
    end
  end

  describe "echo tool" do
    test "echoes the message" do
      context = Context.new()
      params = %{message: "Hello, World!"}
      
      result = Example.execute_tool(:echo, context, params)
      
      refute Context.error?(result)
      assert result.result == %{message: "Hello, World!"}
    end

    test "converts to uppercase when requested" do
      context = Context.new()
      params = %{message: "Hello, World!", uppercase: true}
      
      result = Example.execute_tool(:echo, context, params)
      
      refute Context.error?(result)
      assert result.result == %{message: "HELLO, WORLD!"}
    end
  end

  describe "user resource" do
    test "retrieves an existing user" do
      context = Context.new()
      params = %{id: "1"}
      
      result = Example.query_resource(:user, context, params)
      
      refute Context.error?(result)
      assert result.result == %{id: "1", name: "Alice", email: "alice@example.com"}
    end

    test "returns error for non-existent user" do
      context = Context.new()
      params = %{id: "999"}
      
      result = Example.query_resource(:user, context, params)
      
      assert Context.error?(result)
      assert Context.error(result) == {:not_found, "User not found: 999"}
    end
  end

  describe "component integration" do
    test "registers in the registry" do
      # Start the registry if not already started
      if Process.whereis(GraphOS.Component.Registry) == nil do
        start_supervised!(GraphOS.Component.Registry)
      end
      
      # Register the component
      GraphOS.Component.Registry.register(Example)
      
      # Lookup component
      assert {:ok, component_info} = GraphOS.Component.Registry.lookup_component(Example)
      assert component_info.module == Example
      
      # Lookup tools
      assert {:ok, {Example, tool_info}} = GraphOS.Component.Registry.lookup_tool(:math)
      assert tool_info.name == :math
      
      assert {:ok, {Example, tool_info}} = GraphOS.Component.Registry.lookup_tool(:echo)
      assert tool_info.name == :echo
      
      # Lookup resource
      assert {:ok, {Example, resource_info}} = GraphOS.Component.Registry.lookup_resource(:user)
      assert resource_info.name == :user
    end
    
    test "can be used in a pipeline" do
      # Setup a pipeline with the example component
      pipeline = [
        {Example, prefix: "Pipeline"}
      ]
      
      # Run the pipeline
      context = Context.new()
      result = GraphOS.Component.Pipeline.run(context, pipeline)
      
      # Verify the component modified the context
      assert result.assigns.example_prefix == "Pipeline"
    end
  end
end