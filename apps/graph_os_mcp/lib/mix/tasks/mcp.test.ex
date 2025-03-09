defmodule Mix.Tasks.Mcp.Test do
  @moduledoc """
  Run tests for GraphOS MCP, focusing on the HTTP endpoint tests.

  This task is useful for testing the graph data query functionality specifically.

  ## Usage

      mix mcp.test
  """

  use Mix.Task

  @shortdoc "Run MCP endpoint tests"

  @impl Mix.Task
  def run(args) do
    # Ensure the app is loaded
    Mix.Task.run("app.config")

    # Make sure we're in test environment
    Mix.env(:test)

    # Filter tests to run only the endpoint tests if no args provided
    test_files = case args do
      [] ->
        ["test/graph_os/mcp/http/endpoint_test.exs"]
      _ ->
        args
    end

    # Run the tests
    Mix.Task.run("test", test_files)
  end
end
