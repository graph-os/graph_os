defmodule GraphOS.Protocol.AuthIntegrationTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias GraphOS.Protocol.{GRPC, JSONRPC}

  # Define a simple schema module for testing
  defmodule TestSchema do
    def service_module, do: __MODULE__

    def map_rpc_to_operation("TestMethod", _request),
      do: {:ok, :query, %{path: "test.path", params: %{}}}

    def convert_result_to_proto(result, _method), do: result
  end

  # Define a simple request for testing
  defmodule TestRequest do
    defstruct [:id]
  end

  # Save original config to restore after tests
  setup do
    original_config = Application.get_env(:graph_os_protocol, :auth)

    on_exit(fn ->
      if original_config do
        Application.put_env(:graph_os_protocol, :auth, original_config)
      else
        Application.delete_env(:graph_os_protocol, :auth)
      end
    end)

    # Set test configuration
    Application.put_env(:graph_os_protocol, :auth,
      rpc_secret: "integration_test_secret",
      required: true
    )

    :ok
  end

  describe "Auth integration testing" do
    test "adapter behavior with authentication" do
      # Configure the authentication system directly
      saved_config = Application.get_env(:graph_os_protocol, :auth)

      # Set a known secret for testing
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: true
      )

      try do
        # Create a test connection that simulates a request without a secret
        conn_without_secret = conn(:get, "/test")

        # Process without a secret - should not pass
        result = GraphOS.Protocol.Auth.Plug.call(conn_without_secret, [])
        # Should be halted
        assert result.halted == true
        # Unauthorized status
        assert result.status == 401

        # Create a connection with a secret in headers
        conn_with_header =
          conn(:get, "/test")
          |> put_req_header("x-graphos-rpc-secret", "test_secret")

        # Process with a secret - should pass
        result = GraphOS.Protocol.Auth.Plug.call(conn_with_header, [])
        # Should not be halted
        refute result.halted
      after
        # Restore the original config
        if saved_config do
          Application.put_env(:graph_os_protocol, :auth, saved_config)
        else
          Application.delete_env(:graph_os_protocol, :auth)
        end
      end
    end

    test "auth plug correctly validates and extracts secrets" do
      # Setup for testing
      saved_config = Application.get_env(:graph_os_protocol, :auth)

      # For this test, we'll use a known valid secret
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "valid_secret",
        required: true
      )

      try do
        # Test with a valid secret in header
        conn =
          conn(:get, "/test")
          |> put_req_header("x-graphos-rpc-secret", "valid_secret")

        # This should pass validation
        result = GraphOS.Protocol.Auth.Plug.call(conn, [])
        refute result.halted

        # Test with an invalid secret (should be blocked)
        conn =
          conn(:get, "/test")
          |> put_req_header("x-graphos-rpc-secret", "wrong_secret")

        # This should not pass validation
        result = GraphOS.Protocol.Auth.Plug.call(conn, [])
        assert result.halted
        assert result.status == 401

        # Test with no secret (should be blocked)
        conn = conn(:get, "/test")

        # This should not pass validation since secret is required
        result = GraphOS.Protocol.Auth.Plug.call(conn, [])
        assert result.halted
        assert result.status == 401

        # Now make auth optional
        Application.put_env(:graph_os_protocol, :auth,
          rpc_secret: "valid_secret",
          required: false
        )

        # Test with no secret but auth not required (should pass)
        conn = conn(:get, "/test")

        # First make sure there's no configured secret at all
        Application.put_env(:graph_os_protocol, :auth,
          rpc_secret: nil,
          required: false
        )

        result = GraphOS.Protocol.Auth.Plug.call(conn, [])
        refute result.halted
      after
        # Restore the original config
        if saved_config do
          Application.put_env(:graph_os_protocol, :auth, saved_config)
        else
          Application.delete_env(:graph_os_protocol, :auth)
        end
      end
    end
  end
end
