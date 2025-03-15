defmodule GraphOS.Core.CodeGraphTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph

  alias GraphOS.Core.CodeGraph
  alias GraphOS.Core.CodeParser
  alias GraphOS.Graph

  setup do
    # Initialize the graph store before each test
    :ok = Graph.init()

    # Create a temporary directory for test files
    test_dir = Path.join(System.tmp_dir!(), "graphos_code_graph_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(test_dir)

    # Return the test directory for use in tests
    on_exit(fn ->
      # Clean up the test directory after tests
      File.rm_rf!(test_dir)
    end)

    {:ok, %{test_dir: test_dir}}
  end

  describe "CodeGraph.init/0" do
    test "initializes the graph store" do
      assert :ok = CodeGraph.init()
    end
  end

  describe "CodeGraph.build_graph/2" do
    test "builds a graph from a directory with Elixir files", %{test_dir: test_dir} do
      # Create a sample Elixir file
      sample_module = """
      defmodule GraphOS.Test.SampleModule do
        @moduledoc \"\"\"
        A sample module for testing the code graph.
        \"\"\"

        alias GraphOS.Test.Helper
        import Enum, only: [map: 2]

        @behaviour GenServer

        def hello(name) do
          Helper.format("Hello, \#{name}!")
        end

        def goodbye do
          :ok
        end

        defp internal_function do
          :internal
        end
      end
      """

      sample_helper = """
      defmodule GraphOS.Test.Helper do
        def format(message) do
          String.upcase(message)
        end
      end
      """

      # Write the sample files
      File.write!(Path.join(test_dir, "sample_module.ex"), sample_module)
      File.write!(Path.join(test_dir, "helper.ex"), sample_helper)

      # Build the graph
      {:ok, stats} = CodeGraph.build_graph(test_dir)

      # Verify stats
      assert stats.processed_files == 2
      assert stats.modules == 2
      assert stats.functions >= 3
      assert stats.relationships > 0
    end

    test "handles empty directories", %{test_dir: test_dir} do
      # Empty directory
      {:ok, stats} = CodeGraph.build_graph(test_dir)

      # Verify stats for empty directory
      assert stats.processed_files == 0
      assert stats.modules == 0
      assert stats.functions == 0
      assert stats.relationships == 0
    end

    test "respects non-recursive option", %{test_dir: test_dir} do
      # Create a nested directory
      nested_dir = Path.join(test_dir, "nested")
      File.mkdir_p!(nested_dir)

      # Create a sample file in the main directory
      main_module = """
      defmodule GraphOS.Test.MainModule do
        def main, do: :ok
      end
      """
      File.write!(Path.join(test_dir, "main_module.ex"), main_module)

      # Create a sample file in the nested directory
      nested_module = """
      defmodule GraphOS.Test.NestedModule do
        def nested, do: :ok
      end
      """
      File.write!(Path.join(nested_dir, "nested_module.ex"), nested_module)

      # Build the graph non-recursively
      {:ok, stats} = CodeGraph.build_graph(test_dir, recursive: false)

      # Should only process the main directory file
      assert stats.processed_files == 1
      assert stats.modules == 1
    end
  end

  describe "CodeGraph.module_info/1" do
    test "retrieves information about a module", %{test_dir: test_dir} do
      # Create a sample module
      sample_module = """
      defmodule GraphOS.Test.InfoModule do
        def function1, do: :ok
        def function2(arg), do: arg
      end
      """
      file_path = Path.join(test_dir, "info_module.ex")
      File.write!(file_path, sample_module)

      # Build the graph
      {:ok, stats} = CodeGraph.build_graph(test_dir)

      # Debug: Check if the file was processed
      IO.puts("Build stats: #{inspect(stats)}")

      # Debug: Check what nodes are in the graph
      {:ok, all_nodes} = GraphOS.Graph.Query.find_nodes_by_properties(%{})
      IO.puts("All nodes: #{inspect(Enum.map(all_nodes, & &1.id))}")

      # Debug: Check if the file exists
      IO.puts("File exists: #{File.exists?(file_path)}")

      # Retrieve module info
      result = CodeGraph.get_module_info("GraphOS.Test.InfoModule")
      IO.puts("Module info result: #{inspect(result)}")

      # Assert the result
      assert {:ok, info} = result

      # Verify module info
      assert %{module: module, functions: functions} = info
    end

    test "returns error for non-existent module" do
      # Try to get info for a non-existent module
      assert {:error, _} = CodeGraph.get_module_info("NonExistentModule")
    end
  end

  describe "CodeGraph.update_file/2" do
    test "updates the graph when a file changes", %{test_dir: test_dir} do
      # Create initial file
      initial_module = """
      defmodule GraphOS.Test.UpdateModule do
        def initial, do: :initial
      end
      """
      file_path = Path.join(test_dir, "update_module.ex")
      File.write!(file_path, initial_module)

      # Build initial graph
      {:ok, initial_stats} = CodeGraph.build_graph(test_dir)
      assert initial_stats.functions == 1

      # Update the file
      updated_module = """
      defmodule GraphOS.Test.UpdateModule do
        def initial, do: :initial
        def added, do: :added
      end
      """
      File.write!(file_path, updated_module)

      # Update the graph
      {:ok, update_stats} = CodeGraph.update_file(file_path)

      # Should now have one additional function
      assert update_stats.functions == 2
    end
  end

  describe "GraphOS.Core.CodeParser integration" do
    test "correctly parses Elixir code" do
      # Sample code string
      code = """
      defmodule Test.Parser do
        @moduledoc "Test module for parser"

        alias Test.Helper
        import Enum
        use GenServer

        @behaviour Application

        def start(_type, _args), do: :ok

        defp private_func, do: Helper.help()
      end
      """

      # Parse the code
      {:ok, ast} = CodeParser.parse_string(code)
      result = CodeParser.process_ast(ast, "test.ex")

      # Verify parsing results
      assert length(result.modules) == 1
      assert length(result.functions) == 2

      # Check for dependencies
      dependencies = result.dependencies

      # Should have dependencies for alias, import, use, and behaviour
      dep_types = Enum.map(dependencies, & &1.type)
      assert "references" in dep_types  # for alias
      assert "imports" in dep_types     # for import
      assert "uses" in dep_types        # for use
      assert "implements" in dep_types  # for behaviour
    end
  end
end
