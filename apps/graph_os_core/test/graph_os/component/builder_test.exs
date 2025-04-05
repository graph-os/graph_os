defmodule GraphOS.Component.BuilderTest do
  use ExUnit.Case, async: true
  alias GraphOS.Component.Context

  defmodule TestComponent do
    use GraphOS.Component
    use GraphOS.Component.Builder

    tool(:test_tool,
      description: "A test tool for testing",
      params: [
        name: %{
          name: :name,
          type: :string,
          required: true,
          description: "The name to use"
        },
        count: %{
          name: :count,
          type: :integer,
          default: 1,
          description: "How many items to create"
        }
      ],
      execute: fn context, params ->
        result = "Created #{params.count} items named #{params.name}"
        Context.put_result(context, result)
      end
    )

    tool(:echo_tool,
      description: "Echoes back the input",
      params: [
        message: %{
          name: :message,
          type: :string,
          required: true,
          description: "Message to echo"
        }
      ],
      execute: fn context, params ->
        Context.put_result(context, params.message)
      end
    )

    resource(:test_resource,
      description: "A test resource for testing",
      params: [
        id: %{
          name: :id,
          type: :string,
          required: true,
          description: "The resource ID"
        }
      ],
      query: fn context, params ->
        data = %{id: params.id, name: "Resource #{params.id}"}
        Context.put_result(context, data)
      end
    )

    @impl true
    def call(context, _opts) do
      # Implement the Component behaviour
      context
    end
  end

  describe "tool definition" do
    test "properly registers tools in the component" do
      tools = TestComponent.__tools__()
      assert Map.has_key?(tools, :test_tool)
      assert Map.has_key?(tools, :echo_tool)

      test_tool = tools.test_tool
      assert test_tool.name == :test_tool
      assert test_tool.description == "A test tool for testing"
      assert Map.has_key?(test_tool.params, :name)
      assert Map.has_key?(test_tool.params, :count)
      assert Map.has_key?(test_tool, :execute_fn)
    end

    test "creates execute_tool function for tool execution" do
      context = Context.new()
      params = %{name: "test", count: 3}

      result = TestComponent.execute_tool(:test_tool, context, params)

      assert result.result == "Created 3 items named test"
    end

    test "handles unknown tool execution" do
      context = Context.new()

      result = TestComponent.execute_tool(:unknown_tool, context, %{})

      assert Context.error?(result)
      assert Context.error(result) == {:unknown_tool, "Unknown tool: :unknown_tool"}
    end
  end

  describe "resource definition" do
    test "properly registers resources in the component" do
      resources = TestComponent.__resources__()
      assert Map.has_key?(resources, :test_resource)

      test_resource = resources.test_resource
      assert test_resource.name == :test_resource
      assert test_resource.description == "A test resource for testing"
      assert Map.has_key?(test_resource.params, :id)
      assert Map.has_key?(test_resource, :query_fn)
    end

    test "creates query_resource function for resource queries" do
      context = Context.new()
      params = %{id: "123"}

      result = TestComponent.query_resource(:test_resource, context, params)

      assert result.result == %{id: "123", name: "Resource 123"}
    end

    test "handles unknown resource queries" do
      context = Context.new()

      result = TestComponent.query_resource(:unknown_resource, context, %{})

      assert Context.error?(result)
      assert Context.error(result) == {:unknown_resource, "Unknown resource: :unknown_resource"}
    end
  end
end
