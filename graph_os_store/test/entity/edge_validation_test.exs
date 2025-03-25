defmodule GraphOS.Entity.EdgeValidationTest do
  use ExUnit.Case, async: true

  # Define test modules for different node types
  defmodule TestGraph do
    use GraphOS.Entity.Graph
  end

  defmodule NodeTypeA do
    use GraphOS.Entity.Node,
      graph: TestGraph

    def data_schema do
      [%{name: :id, type: :string, required: true}]
    end
  end

  defmodule NodeTypeB do
    use GraphOS.Entity.Node,
      graph: TestGraph

    def data_schema do
      [%{name: :id, type: :string, required: true}]
    end
  end

  defmodule NodeTypeC do
    use GraphOS.Entity.Node,
      graph: TestGraph

    def data_schema do
      [%{name: :id, type: :string, required: true}]
    end
  end

  # Define edges with different constraints
  defmodule EdgeWithInclude do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: [include: NodeTypeA],
      target: [include: NodeTypeB]
  end

  defmodule EdgeWithExclude do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: [exclude: NodeTypeC],
      target: [exclude: NodeTypeC]
  end

  defmodule EdgeWithBoth do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: [include: [NodeTypeA, NodeTypeB], exclude: NodeTypeB],
      target: [include: [NodeTypeA, NodeTypeB], exclude: NodeTypeB]
  end

  alias GraphOS.Entity.Binding

  # Direct tests of binding logic which is the core of edge validation
  describe "Binding allowed?/2 logic" do
    test "include only allows listed modules" do
      binding = Binding.new(include: [NodeTypeA, NodeTypeB])
      assert Binding.allowed?(binding, NodeTypeA) == true
      assert Binding.allowed?(binding, NodeTypeB) == true
      assert Binding.allowed?(binding, NodeTypeC) == false
    end

    test "exclude disallows listed modules" do
      binding = Binding.new(exclude: [NodeTypeC])
      assert Binding.allowed?(binding, NodeTypeA) == true
      assert Binding.allowed?(binding, NodeTypeB) == true
      assert Binding.allowed?(binding, NodeTypeC) == false
    end

    test "both include and exclude require satisfying both conditions" do
      binding = Binding.new(include: [NodeTypeA, NodeTypeB], exclude: [NodeTypeB])
      assert Binding.allowed?(binding, NodeTypeA) == true
      assert Binding.allowed?(binding, NodeTypeB) == false
      assert Binding.allowed?(binding, NodeTypeC) == false
    end

    test "empty binding allows all modules" do
      binding = Binding.new([])
      assert Binding.allowed?(binding, NodeTypeA) == true
      assert Binding.allowed?(binding, NodeTypeB) == true
      assert Binding.allowed?(binding, NodeTypeC) == true
    end
  end

  # Test the validate_source_type and validate_target_type functions directly
  describe "Edge validation functions" do
    test "validate_source_type checks source module against binding" do
      # For include binding
      source_binding = Binding.new(include: [NodeTypeA])
      assert :ok = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeA, source_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeB, source_binding)

      # For exclude binding
      source_binding = Binding.new(exclude: [NodeTypeC])
      assert :ok = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeA, source_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeC, source_binding)

      # For both include and exclude
      source_binding = Binding.new(include: [NodeTypeA, NodeTypeB], exclude: [NodeTypeB])
      assert :ok = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeA, source_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeB, source_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeC, source_binding)
    end

    test "validate_target_type checks target module against binding" do
      # For include binding
      target_binding = Binding.new(include: [NodeTypeB])
      assert :ok = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeB, target_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeA, target_binding)

      # For exclude binding
      target_binding = Binding.new(exclude: [NodeTypeC])
      assert :ok = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeA, target_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeC, target_binding)

      # For both include and exclude
      target_binding = Binding.new(include: [NodeTypeA, NodeTypeB], exclude: [NodeTypeB])
      assert :ok = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeA, target_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeB, target_binding)
      assert {:error, _} = GraphOS.Entity.Edge.validate_target_type(nil, NodeTypeC, target_binding)
    end
  end

  # Test the Edge module bindings to check the implementation
  describe "Edge module bindings" do
    test "EdgeWithInclude correctly configures source and target bindings" do
      entity = EdgeWithInclude.entity()

      # Source binding should include NodeTypeA only
      assert entity.source.include == [NodeTypeA]
      assert entity.source.exclude == []

      # Target binding should include NodeTypeB only
      assert entity.target.include == [NodeTypeB]
      assert entity.target.exclude == []
    end

    test "EdgeWithExclude correctly configures source and target bindings" do
      entity = EdgeWithExclude.entity()

      # Source binding should exclude NodeTypeC
      assert entity.source.include == []
      assert entity.source.exclude == [NodeTypeC]

      # Target binding should exclude NodeTypeC
      assert entity.target.include == []
      assert entity.target.exclude == [NodeTypeC]
    end

    test "EdgeWithBoth correctly configures source and target bindings" do
      entity = EdgeWithBoth.entity()

      # Source binding should include NodeTypeA and NodeTypeB, but exclude NodeTypeB
      assert Enum.sort(entity.source.include) == Enum.sort([NodeTypeA, NodeTypeB])
      assert entity.source.exclude == [NodeTypeB]

      # Target binding should include NodeTypeA and NodeTypeB, but exclude NodeTypeB
      assert Enum.sort(entity.target.include) == Enum.sort([NodeTypeA, NodeTypeB])
      assert entity.target.exclude == [NodeTypeB]
    end
  end

  # Test error messages for validation failures
  describe "Validation error messages" do
    test "not in include list error message is descriptive" do
      binding = Binding.new(include: [NodeTypeA])

      {:error, error_message} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeB, binding)
      assert String.contains?(error_message, "not in the allowed include list")
    end

    test "in exclude list error message is descriptive" do
      binding = Binding.new(exclude: [NodeTypeC])

      {:error, error_message} = GraphOS.Entity.Edge.validate_source_type(nil, NodeTypeC, binding)
      assert String.contains?(error_message, "explicitly excluded")
    end
  end

  # Test the edge module hooks
  describe "Edge module before_insert/update hooks" do
    test "validate types against bindings in hooks" do
      # We're not testing the full validate_edge_types function as it depends on Store.get
      # Instead we're testing the validation logic in isolation
      source_binding = Binding.new(include: [NodeTypeA])
      target_binding = Binding.new(include: [NodeTypeB])

      # Valid combination
      assert :ok = GraphOS.Entity.Edge.validate_types(
        nil, NodeTypeA, NodeTypeB, source_binding, target_binding
      )

      # Invalid source
      assert {:error, _} = GraphOS.Entity.Edge.validate_types(
        nil, NodeTypeC, NodeTypeB, source_binding, target_binding
      )

      # Invalid target
      assert {:error, _} = GraphOS.Entity.Edge.validate_types(
        nil, NodeTypeA, NodeTypeC, source_binding, target_binding
      )

      # Both invalid
      assert {:error, _} = GraphOS.Entity.Edge.validate_types(
        nil, NodeTypeC, NodeTypeC, source_binding, target_binding
      )
    end
  end
end
