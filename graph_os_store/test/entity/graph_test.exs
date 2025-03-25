defmodule GraphOS.Entity.GraphTest do
  use ExUnit.Case, async: true

  alias GraphOS.Entity.Graph
  alias GraphOS.Entity.Metadata

  describe "new/1" do
    test "creates a graph with default values" do
      graph = Graph.new(%{})

      assert is_binary(graph.id)
      assert String.length(graph.id) > 0
      assert graph.name == nil
      assert %Metadata{} = graph.metadata
      assert graph.metadata.entity == :graph
      assert graph.metadata.module == Graph
    end

    test "creates a graph with provided values" do
      graph = Graph.new(%{
        id: "graph-123",
        name: "Test Graph",
        module: __MODULE__
      })

      assert graph.id == "graph-123"
      assert graph.name == "Test Graph"
      assert graph.metadata.module == __MODULE__
    end

    test "sets metadata correctly" do
      custom_metadata = Metadata.new(%{entity: :graph, module: __MODULE__})
      graph = Graph.new(%{metadata: custom_metadata})

      assert graph.metadata == custom_metadata
    end
  end

  describe "schema/0" do
    test "returns a valid schema definition" do
      schema = Graph.schema()

      assert schema.name == :graph
      assert is_list(schema.fields)

      field_names = Enum.map(schema.fields, &Map.get(&1, :name))
      assert :id in field_names
      assert :name in field_names
      assert :metadata in field_names

      id_field = Enum.find(schema.fields, &(&1.name == :id))
      assert id_field.required == true
      assert id_field.type == :string

      name_field = Enum.find(schema.fields, &(&1.name == :name))
      assert name_field.type == :string
      assert name_field.default == ""
    end
  end

  # Test custom graph module using GraphOS.Entity.Graph
  defmodule CustomGraph do
    use GraphOS.Entity.Graph, temp: true

    @impl GraphOS.Entity.Graph.Behaviour
    def on_start(_options) do
      {:ok, %{started: true}}
    end

    @impl GraphOS.Entity.Graph.Behaviour
    def on_stop(state) do
      {:ok, Map.put(state, :stopped, true)}
    end

    # Override the new function completely, replacing the one defined by use
    defoverridable new: 1

    def new(attrs) do
      attrs_with_metadata = if is_map(attrs) do
        Map.put_new(attrs, :metadata, GraphOS.Entity.Metadata.new(%{entity: :graph, module: __MODULE__}))
      else
        %{metadata: GraphOS.Entity.Metadata.new(%{entity: :graph, module: __MODULE__})}
      end

      GraphOS.Entity.Graph.new(attrs_with_metadata)
    end
  end

  describe "using GraphOS.Entity.Graph" do
    test "defines a new module with correct callbacks" do
      # Check that the callback functions are defined
      assert function_exported?(CustomGraph, :on_start, 1)
      assert function_exported?(CustomGraph, :on_stop, 1)

      # Test the callbacks
      assert {:ok, %{started: true}} = CustomGraph.on_start([])
      assert {:ok, %{started: true, stopped: true}} = CustomGraph.on_stop(%{started: true})
    end

    test "includes entity metadata in the module" do
      # Create a custom graph instance
      custom_graph = CustomGraph.new(%{name: "Custom Graph"})

      # Check that it's a valid graph
      assert %Graph{} = custom_graph
      assert custom_graph.name == "Custom Graph"

      # Check that the metadata includes the correct module
      assert custom_graph.metadata.module == CustomGraph
      assert custom_graph.metadata.entity == :graph
    end
  end

  describe "Graph.Behaviour" do
    test "defines a behaviour with the correct callbacks" do
      # Check that the behaviour defines the required callbacks
      assert function_exported?(GraphOS.Entity.Graph.Behaviour, :behaviour_info, 1)

      # Get the callbacks using behaviour_info
      callbacks = GraphOS.Entity.Graph.Behaviour.behaviour_info(:callbacks)

      # Verify that the expected callbacks are defined
      assert {:on_start, 1} in callbacks
      assert {:on_stop, 1} in callbacks
    end
  end
end
