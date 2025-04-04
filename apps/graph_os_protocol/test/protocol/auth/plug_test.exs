defmodule GraphOS.Protocol.Auth.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias GraphOS.Protocol.Auth.Plug

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

    # Setup test config with a known secret
    Application.put_env(:graph_os_protocol, :auth,
      rpc_secret: "test_plug_secret",
      required: true
    )

    :ok
  end

  # Direct testing of the auth functionality
  describe "Auth functionality" do
    test "validates correct secrets" do
      # Test the direct validation through Auth.Secret
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: true
      )

      assert GraphOS.Protocol.Auth.Secret.validate("test_secret") == :ok
      assert GraphOS.Protocol.Auth.Secret.validate("wrong_secret") == {:error, :invalid_secret}
      assert GraphOS.Protocol.Auth.Secret.validate(nil) == {:error, :missing_secret}

      # Make auth optional
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: false
      )

      assert GraphOS.Protocol.Auth.Secret.validate(nil) == :ok
    end

    test "honors authentication requirement setting" do
      # When required is true
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: true
      )

      assert GraphOS.Protocol.Auth.Secret.required?() == true

      # When required is false
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: false
      )

      assert GraphOS.Protocol.Auth.Secret.required?() == false

      # When not specified (defaults to true)
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret")
      assert GraphOS.Protocol.Auth.Secret.required?() == true
    end

    test "validates correct secrets even when auth is optional" do
      # Make auth optional but still validate provided secrets
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: false
      )

      # Valid secret should succeed
      assert GraphOS.Protocol.Auth.Secret.validate("test_secret") == :ok

      # Invalid secret should fail even when auth is optional
      assert GraphOS.Protocol.Auth.Secret.validate("wrong_secret") == {:error, :invalid_secret}

      # Missing secret (nil) should be allowed when auth is optional
      assert GraphOS.Protocol.Auth.Secret.validate(nil) == :ok
    end
  end

  # Test the plug behavior directly
  describe "Plug behavior" do
    test "enforces authentication when required" do
      # Set a consistent environment for this test
      saved_config = Application.get_env(:graph_os_protocol, :auth)

      try do
        # Configure for testing
        Application.put_env(:graph_os_protocol, :auth,
          rpc_secret: "test_secret",
          required: true
        )

        # Test case 1: No secret provided - should fail with 401
        conn = conn(:get, "/test")
        result = Plug.call(conn, [])
        # Conn should be halted
        assert result.halted == true
        assert result.status == 401

        # Test case 2: Valid secret in headers - should pass
        conn =
          conn(:get, "/test")
          |> put_req_header("x-graphos-rpc-secret", "test_secret")

        result = Plug.call(conn, [])
        # Conn should not be halted
        refute result.halted

        # Test case 3: Valid secret in Authorization header - should pass
        conn =
          conn(:get, "/test")
          |> put_req_header("authorization", "Bearer test_secret")

        result = Plug.call(conn, [])
        # Conn should not be halted
        refute result.halted

        # Test case 4: Secret in assigns - should pass
        conn =
          conn(:get, "/test")
          |> Map.put(:assigns, %{rpc_secret: "test_secret"})

        result = Plug.call(conn, [])
        # Conn should not be halted
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

  test "allows requests when auth is not required" do
    # Set auth to optional for this test
    saved_config = Application.get_env(:graph_os_protocol, :auth)

    try do
      Application.put_env(:graph_os_protocol, :auth,
        rpc_secret: "test_secret",
        required: false
      )

      # No secret provided but auth not required - should pass
      conn = conn(:get, "/test")
      result = Plug.call(conn, [])
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
