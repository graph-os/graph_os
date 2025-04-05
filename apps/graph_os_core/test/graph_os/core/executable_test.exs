defmodule GraphOS.Core.ExecutableTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph

  alias GraphOS.Store # Use the main Store API
  alias GraphOS.Entity.Node # Use the Node entity schema
  # alias GraphOS.Core.Executable # Module does not exist

  # Start the default store once for all tests
  setup_all do
    # Ensure the default store is configured and started
    # This assumes config/test.exs defines the :default store adapter
    # And the store is added to the test application supervision tree
    # If not, we might need to start it manually here:
    # {:ok, _pid} = start_supervised({GraphOS.Store, name: :default})
    :ok
  end

  describe "GraphOS.Core.Executable protocol" do

    # TODO: Re-enable or rewrite these tests when node execution is implemented

    # test "Node implementation returns not_executable for regular nodes" do
    #   # Create a regular node without executable properties
    #   {:ok, node} = Store.insert(Node, %{id: "test_node", type: "test", data: %{name: "test_node"}})
    #
    #   # Attempt to execute it
    #   result = Executable.execute(node) # Executable doesn't exist
    #   assert result == {:error, :not_executable}
    # end

    # test "Node implementation executes code from executable property" do
    #   # Create a node with executable code in its data map
    #   {:ok, node} =
    #     Store.insert(Node, %{
    #       id: "code_node",
    #       type: "test",
    #       data: %{
    #         name: "code_node",
    #         executable: "context[:value] * 2"
    #       }
    #     })
    #
    #   # Execute it with context
    #   result = Executable.execute(node, %{value: 21}) # Executable doesn't exist
    #   assert result == {:ok, 42}
    # end

    # test "Node implementation executes code by type" do
    #   # Create a node with executable type and code
    #   {:ok, node} =
    #     Store.insert(Node, %{
    #       id: "typed_node",
    #       type: "test",
    #       data: %{
    #         name: "typed_node",
    #         executable_type: "elixir_code",
    #         executable: "context[:a] + context[:b]"
    #       }
    #     })
    #
    #   # Execute it with context
    #   result = Executable.execute(node, %{a: 20, b: 22}) # Executable doesn't exist
    #   assert result == {:ok, 42}
    # end

    # test "Node implementation returns error for unknown executable type" do
    #   # Create a node with unknown executable type
    #   {:ok, node} =
    #     Store.insert(Node, %{
    #       id: "unknown_type_node",
    #       type: "test",
    #       data: %{
    #         name: "unknown_type_node",
    #         executable_type: "unknown_type",
    #         executable: "some_code"
    #       }
    #     })
    #
    #   # Attempt to execute it
    #   result = Executable.execute(node) # Executable doesn't exist
    #   assert {:error, {:unknown_executable_type, "unknown_type"}} = result
    # end

    # test "Node execution handles errors gracefully" do
    #   # Create a node with executable code that will raise an error
    #   {:ok, node} =
    #     Store.insert(Node, %{
    #       id: "error_node",
    #       type: "test",
    #       data: %{
    #         name: "error_node",
    #         # Will raise a divide by zero error
    #         executable: "1 / 0"
    #       }
    #     })
    #
    #   # Execute it
    #   result = Executable.execute(node) # Executable doesn't exist
    #   assert {:error, {:execution_error, _}} = result
    # end

  end
end
