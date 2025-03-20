defmodule GraphOS.Core.ExecutableTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph

  alias GraphOS.GraphContext.Node
  alias GraphOS.Core.Executable

  setup do
    # Initialize the ETS store directly to avoid dependency on GraphOS.GraphContext.init
    GraphOS.GraphContext.Store.ETS.init([])
    :ok
  end

  describe "GraphOS.Core.Executable protocol" do

    test "GraphOS.GraphContext.Node implementation returns not_executable for regular nodes" do
      # Create a regular node without executable properties
      node = Node.new(%{name: "test_node"}, id: "test_node")

      # Attempt to execute it
      result = Executable.execute(node)
      assert result == {:error, :not_executable}
    end

    test "GraphOS.GraphContext.Node implementation executes code from executable property" do
      # Create a node with executable code
      node =
        Node.new(
          %{
            name: "code_node",
            executable: "context[:value] * 2"
          },
          id: "code_node"
        )

      # Execute it with context
      result = Executable.execute(node, %{value: 21})
      assert result == {:ok, 42}
    end

    test "GraphOS.GraphContext.Node implementation executes code by type" do
      # Create a node with executable type and code
      node =
        Node.new(
          %{
            name: "typed_node",
            executable_type: "elixir_code",
            executable: "context[:a] + context[:b]"
          },
          id: "typed_node"
        )

      # Execute it with context
      result = Executable.execute(node, %{a: 20, b: 22})
      assert result == {:ok, 42}
    end

    test "GraphOS.GraphContext.Node implementation returns error for unknown executable type" do
      # Create a node with unknown executable type
      node =
        Node.new(
          %{
            name: "unknown_type_node",
            executable_type: "unknown_type",
            executable: "some_code"
          },
          id: "unknown_type_node"
        )

      # Attempt to execute it
      result = Executable.execute(node)
      assert {:error, {:unknown_executable_type, "unknown_type"}} = result
    end

    test "node execution handles errors gracefully" do
      # Create a node with executable code that will raise an error
      node =
        Node.new(
          %{
            name: "error_node",
            # Will raise a divide by zero error
            executable: "1 / 0"
          },
          id: "error_node"
        )

      # Execute it
      result = Executable.execute(node)
      assert {:error, {:execution_error, _}} = result
    end
  end
end
