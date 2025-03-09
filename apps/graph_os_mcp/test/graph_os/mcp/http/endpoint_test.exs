defmodule GraphOS.MCP.HTTP.EndpointTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Mox

  # Define mocks
  setup :verify_on_exit!

  alias GraphOS.MCP.HTTP.Endpoint

  # Set dev mode for tests
  setup do
    original_value = Application.get_env(:graph_os_mcp, :dev_mode)
    Application.put_env(:graph_os_mcp, :dev_mode, true)

    on_exit(fn ->
      Application.put_env(:graph_os_mcp, :dev_mode, original_value)
    end)

    :ok
  end

  # Note: The dev UI and graph-related tests have been removed as these routes
  # have been moved to the graph_os_dev app.

  # Add test for the health endpoint which should still be in MCP
  describe "health endpoint" do
    test "GET /health returns health information" do
      conn = conn(:get, "/health")
      |> Endpoint.call([])

      assert conn.status == 200

      response = Jason.decode!(conn.resp_body)
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
    end
  end

  # Helper functions can be added here if needed
end
