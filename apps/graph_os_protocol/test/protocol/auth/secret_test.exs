defmodule GraphOS.Protocol.Auth.SecretTest do
  use ExUnit.Case, async: false
  alias GraphOS.Protocol.Auth.Secret

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

    :ok
  end

  describe "get_secret/0" do
    test "returns nil when no config exists" do
      Application.delete_env(:graph_os_protocol, :auth)
      assert Secret.get_secret() == nil
    end

    test "returns the configured secret" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret")
      assert Secret.get_secret() == "test_secret"
    end
  end

  describe "required?/0" do
    test "returns false when no config exists" do
      Application.delete_env(:graph_os_protocol, :auth)
      refute Secret.required?()
    end

    test "returns true by default when config exists" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret")
      assert Secret.required?()
    end

    test "returns configured value when explicitly set" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret", required: false)
      refute Secret.required?()

      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret", required: true)
      assert Secret.required?()
    end
  end

  describe "validate/1" do
    test "returns :ok when authentication is not required" do
      Application.put_env(:graph_os_protocol, :auth, required: false)
      assert Secret.validate(nil) == :ok
    end

    test "returns {:error, :missing_secret} when required and no secret provided" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret", required: true)
      assert Secret.validate(nil) == {:error, :missing_secret}
    end

    test "returns :ok when secret matches configured secret" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret", required: true)
      assert Secret.validate("test_secret") == :ok
    end

    test "returns {:error, :invalid_secret} when secret doesn't match" do
      Application.put_env(:graph_os_protocol, :auth, rpc_secret: "test_secret", required: true)
      assert Secret.validate("wrong_secret") == {:error, :invalid_secret}
    end
  end

  # We can't test private functions directly, so we'll test the validation function
  # with identical and differing secrets to ensure the comparison works
  test "validation compares secrets correctly" do
    # Configure a known secret
    Application.put_env(:graph_os_protocol, :auth,
      rpc_secret: "test_secret",
      required: true
    )

    # Same secret should validate
    assert Secret.validate("test_secret") == :ok

    # Different secret should fail
    assert Secret.validate("test_Secret") == {:error, :invalid_secret}
    assert Secret.validate("TEST_SECRET") == {:error, :invalid_secret}
    assert Secret.validate("wrong") == {:error, :invalid_secret}
  end
end
