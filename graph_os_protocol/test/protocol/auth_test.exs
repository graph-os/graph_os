defmodule GraphOS.Protocol.AuthTest do
  use ExUnit.Case, async: false
  alias GraphOS.Protocol.Auth

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
      rpc_secret: "test_auth_secret",
      required: true
    )

    :ok
  end

  test "validate_secret/1 validates the secret" do
    # Valid secret
    assert Auth.validate_secret("test_auth_secret") == :ok

    # Invalid secret
    assert Auth.validate_secret("wrong_secret") == {:error, :invalid_secret}

    # No secret
    assert Auth.validate_secret(nil) == {:error, :missing_secret}
  end

  test "get_secret/0 returns the configured secret" do
    assert Auth.get_secret() == "test_auth_secret"
  end

  test "required?/0 returns the authentication requirement" do
    # When required is true
    Application.put_env(:graph_os_protocol, :auth,
      rpc_secret: "test_auth_secret",
      required: true
    )

    assert Auth.required?() == true

    # When required is false
    Application.put_env(:graph_os_protocol, :auth,
      rpc_secret: "test_auth_secret",
      required: false
    )

    assert Auth.required?() == false
  end
end
