defmodule GraphOS.Component.RegistryTest do
  use ExUnit.Case
  alias GraphOS.Component
  alias GraphOS.Component.Registry

  defmodule TestComponent do
    use Component
    use GraphOS.Component.Builder

    tool :test_tool,
      description: "A test tool for testing",
      params: [
        name: %{
          name: :name,
          type: :string,
          required: true,
          description: "The name to use"
        }
      ],
      execute: fn context, _params ->
        context
      end

    resource :test_resource,
      description: "A test resource for testing",
      params: [
        id: %{
          name: :id,
          type: :string,
          required: true,
          description: "The resource ID"
        }
      ],
      query: fn context, _params ->
        context
      end

    @impl true
    def call(context, _opts) do
      context
    end
  end

  defmodule AnotherComponent do
    use Component
    use GraphOS.Component.Builder

    tool :another_tool,
      description: "Another test tool",
      params: [
        data: %{
          name: :data,
          type: :map,
          required: true,
          description: "Data to process"
        }
      ],
      execute: fn context, _params ->
        context
      end

    @impl true
    def call(context, _opts) do
      context
    end
  end

  defmodule InvalidModule do
    # Not a component, missing call/2
  end

  setup do
    # Clear the registry table between tests instead of restarting
    :ets.delete_all_objects(:graphos_component_registry)
    :ok
  end

  describe "register/1" do
    test "successfully registers a valid component" do
      assert :ok = Registry.register(TestComponent)
      
      # Verify component was registered
      assert {:ok, component_info} = Registry.lookup_component(TestComponent)
      assert component_info.module == TestComponent
      assert map_size(component_info.tools) == 1
      assert map_size(component_info.resources) == 1
      
      # Verify tool was registered
      assert {:ok, {component, tool_info}} = Registry.lookup_tool(:test_tool)
      assert component == TestComponent
      assert tool_info.name == :test_tool
      assert tool_info.description == "A test tool for testing"
      
      # Verify resource was registered
      assert {:ok, {component, resource_info}} = Registry.lookup_resource(:test_resource)
      assert component == TestComponent
      assert resource_info.name == :test_resource
    end

    test "fails to register an invalid module" do
      assert {:error, _} = Registry.register(InvalidModule)
      assert {:error, :not_found} = Registry.lookup_component(InvalidModule)
    end
  end

  describe "register_many/1" do
    test "registers multiple components" do
      assert :ok = Registry.register_many([TestComponent, AnotherComponent])
      
      assert {:ok, _} = Registry.lookup_component(TestComponent)
      assert {:ok, _} = Registry.lookup_component(AnotherComponent)
      assert {:ok, _} = Registry.lookup_tool(:test_tool)
      assert {:ok, _} = Registry.lookup_tool(:another_tool)
    end

    test "returns errors for invalid components" do
      assert {:error, _} = Registry.register_many([TestComponent, InvalidModule])
      
      # The valid component should still be registered
      assert {:ok, _} = Registry.lookup_component(TestComponent)
      assert {:error, :not_found} = Registry.lookup_component(InvalidModule)
    end
  end

  describe "lookup functions" do
    setup do
      Registry.register_many([TestComponent, AnotherComponent])
      :ok
    end

    test "lookup_component/1 finds registered components" do
      assert {:ok, info} = Registry.lookup_component(TestComponent)
      assert info.module == TestComponent
      
      assert {:error, :not_found} = Registry.lookup_component(InvalidModule)
    end

    test "lookup_tool/1 finds registered tools" do
      assert {:ok, {TestComponent, tool_info}} = Registry.lookup_tool(:test_tool)
      assert tool_info.name == :test_tool
      
      assert {:ok, {AnotherComponent, tool_info}} = Registry.lookup_tool(:another_tool)
      assert tool_info.name == :another_tool
      
      assert {:error, :not_found} = Registry.lookup_tool(:non_existent_tool)
    end

    test "lookup_resource/1 finds registered resources" do
      assert {:ok, {TestComponent, resource_info}} = Registry.lookup_resource(:test_resource)
      assert resource_info.name == :test_resource
      
      assert {:error, :not_found} = Registry.lookup_resource(:non_existent_resource)
    end
  end

  describe "list functions" do
    setup do
      Registry.register_many([TestComponent, AnotherComponent])
      :ok
    end

    test "list_components/0 returns all registered components" do
      components = Registry.list_components()
      assert length(components) == 2
      
      component_modules = Enum.map(components, fn {module, _info} -> module end)
      assert TestComponent in component_modules
      assert AnotherComponent in component_modules
    end

    test "list_tools/0 returns all registered tools" do
      tools = Registry.list_tools()
      assert length(tools) == 2
      
      tool_names = Enum.map(tools, fn {name, _info} -> name end)
      assert :test_tool in tool_names
      assert :another_tool in tool_names
    end

    test "list_resources/0 returns all registered resources" do
      resources = Registry.list_resources()
      assert length(resources) == 1
      
      resource_names = Enum.map(resources, fn {name, _info} -> name end)
      assert :test_resource in resource_names
    end
  end
end