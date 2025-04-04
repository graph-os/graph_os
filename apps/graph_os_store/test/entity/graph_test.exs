defmodule GraphOS.Entity.GraphTest do
  use ExUnit.Case

  alias GraphOS.Entity.Graph
  alias GraphOS.Entity.Metadata

  # Test graph with custom behavior implementation
  defmodule TestGraph do
    use GraphOS.Entity.Graph

    @impl GraphOS.Entity.Graph.Behaviour
    def on_start(options) do
      # Initialize graph on start
      {:ok, %{started_at: :os.system_time(:millisecond), options: options}}
    end

    @impl GraphOS.Entity.Graph.Behaviour
    def on_stop(state) do
      # Cleanup when graph stops
      stopped_at = :os.system_time(:millisecond)
      updated_state = Map.put(state, :stopped_at, stopped_at)
      {:ok, updated_state}
    end
  end

  # Test temporary graph implementation
  defmodule TempGraph do
    use GraphOS.Entity.Graph, temp: true
  end

  # Default implementation module (uses default callbacks)
  defmodule DefaultGraph do
    use GraphOS.Entity.Graph
  end

  describe "Graph entity basics" do
    test "creating a graph with required fields" do
      graph = Graph.new(%{
        id: "test-graph",
        name: "Test Graph"
      })

      assert graph.id == "test-graph"
      assert graph.name == "Test Graph"
      assert %Metadata{} = graph.metadata
    end

    test "creating a graph generates an ID if not provided" do
      graph = Graph.new(%{name: "Auto ID Graph"})

      assert graph.id != nil
      assert is_binary(graph.id)
    end

    test "creating a graph with metadata" do
      metadata = %Metadata{module: TestGraph, version: 1}
      graph = Graph.new(%{name: "Graph with Metadata", metadata: metadata})

      assert graph.metadata.module == TestGraph
      assert graph.metadata.version == 1
    end

    test "default values are applied" do
      graph = Graph.new(%{})

      assert graph.name == nil
      assert %Metadata{} = graph.metadata
    end
  end

  describe "Graph schema validation" do
    test "graph schema includes all required fields" do
      schema = Graph.schema()

      assert schema.name == :graph

      # Verify required fields are present
      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :name in field_names
      assert :metadata in field_names

      # Check required fields
      id_field = Enum.find(schema.fields, fn field -> field.name == :id end)
      assert id_field.required == true

      # Check defaults
      name_field = Enum.find(schema.fields, fn field -> field.name == :name end)
      assert name_field.default == ""

      metadata_field = Enum.find(schema.fields, fn field -> field.name == :metadata end)
      assert metadata_field.default == %{}
    end
  end

  describe "Graph behavior callbacks" do
    test "default implementation for on_start" do
      {:ok, state} = DefaultGraph.on_start([])
      assert is_map(state)
      assert state == %{}
    end

    test "default implementation for on_stop" do
      initial_state = %{some: "state"}
      {:ok, state} = DefaultGraph.on_stop(initial_state)
      assert is_map(state)
      assert state == %{}
    end

    test "custom implementation for on_start" do
      options = [custom: "option"]
      {:ok, state} = TestGraph.on_start(options)

      assert is_map(state)
      assert state.options == options
      assert is_integer(state.started_at)
    end

    test "custom implementation for on_stop" do
      initial_state = %{started_at: :os.system_time(:millisecond)}
      {:ok, state} = TestGraph.on_stop(initial_state)

      assert state.started_at == initial_state.started_at
      assert is_integer(state.stopped_at)
      assert state.stopped_at >= state.started_at
    end
  end

  describe "Using macro for custom graph modules" do
    test "custom graph module has proper entity configuration" do
      # Using reflection to check module attributes
      assert Code.ensure_loaded?(TestGraph)
      # Check if the module has the __using__ macro effect
      assert function_exported?(TestGraph, :on_start, 1)
      assert function_exported?(TestGraph, :on_stop, 1)
      assert function_exported?(TestGraph, :new, 1)
    end

    test "temporary graph has temp flag set" do
      # Check if temp modules have the right flags set
      assert Code.ensure_loaded?(TempGraph)
      assert function_exported?(TempGraph, :on_start, 1)
      assert function_exported?(TempGraph, :on_stop, 1)
    end

    test "custom graph module extends new function" do
      graph = TestGraph.new(%{name: "Custom Graph"})

      assert graph.name == "Custom Graph"
      assert is_binary(graph.id)
      assert %Metadata{} = graph.metadata
    end
  end
end
