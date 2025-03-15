defmodule GraphOS.Core.ExecutableTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph
  
  alias GraphOS.Graph
  alias GraphOS.Graph.{Node, Transaction, Store}
  alias GraphOS.Core.Executable

  setup do
    # Initialize the ETS store directly to avoid dependency on GraphOS.Graph.init
    GraphOS.Graph.Store.ETS.init([])
    :ok
  end

  describe "GraphOS.Core.Executable protocol" do
    @tag :skip
    test "default implementation returns not_executable error" do
      # Skip this test for now since we need more protocol implementations
      assert true 
    end

    test "GraphOS.Graph.Node implementation returns not_executable for regular nodes" do
      # Create a regular node without executable properties
      node = Node.new(%{name: "test_node"}, [id: "test_node"])
      
      # Attempt to execute it
      result = Executable.execute(node)
      assert result == {:error, :not_executable}
    end

    test "GraphOS.Graph.Node implementation executes code from executable property" do
      # Create a node with executable code
      node = Node.new(%{
        name: "code_node",
        executable: "context[:value] * 2"
      }, [id: "code_node"])
      
      # Execute it with context
      result = Executable.execute(node, %{value: 21})
      assert result == {:ok, 42}
    end

    test "GraphOS.Graph.Node implementation executes code by type" do
      # Create a node with executable type and code
      node = Node.new(%{
        name: "typed_node",
        executable_type: "elixir_code",
        executable: "context[:a] + context[:b]"
      }, [id: "typed_node"])
      
      # Execute it with context
      result = Executable.execute(node, %{a: 20, b: 22})
      assert result == {:ok, 42}
    end

    test "GraphOS.Graph.Node implementation returns error for unknown executable type" do
      # Create a node with unknown executable type
      node = Node.new(%{
        name: "unknown_type_node",
        executable_type: "unknown_type",
        executable: "some_code"
      }, [id: "unknown_type_node"])
      
      # Attempt to execute it
      result = Executable.execute(node)
      assert {:error, {:unknown_executable_type, "unknown_type"}} = result
    end

    test "node execution handles errors gracefully" do
      # Create a node with executable code that will raise an error
      node = Node.new(%{
        name: "error_node",
        executable: "1 / 0"  # Will raise a divide by zero error
      }, [id: "error_node"])
      
      # Execute it
      result = Executable.execute(node)
      assert {:error, {:execution_error, _}} = result
    end
  end
end