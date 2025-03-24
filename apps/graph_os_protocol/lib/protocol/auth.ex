defmodule GraphOS.Protocol.Auth do
  use Boundary, exports: [Secret]

  @moduledoc """
  Authentication utilities for GraphOS protocol interfaces.

  This module provides a centralized authentication system for all GraphOS protocol
  interfaces (gRPC, JSON-RPC, HTTP). It's built to protect GraphOS services from
  unauthorized access from different users on the same machine.

  ## Key Features

  1. **Secret-based authentication** - Uses a configurable secret key (GRAPH_OS_RPC_SECRET)
  2. **Pluggable architecture** - Easily added to protocol adapters with minimal configuration
  3. **Multiple transport support** - Works with HTTP headers, gRPC metadata, or custom transports
  4. **Environment-specific configuration** - Different settings for dev, test, and production

  ## Configuration

  Configure the authentication secret in your environment config files:

  ```elixir
  # In config/dev.exs (do NOT use this secret in production)
  config :graph_os_protocol, :auth,
    rpc_secret: "dev_only_secret_key",
    required: true

  # In config/runtime.exs (for production)
  config :graph_os_protocol, :auth,
    rpc_secret: System.get_env("GRAPH_OS_RPC_SECRET"),
    required: true
  ```

  ## Client Usage

  When implementing a client that connects to GraphOS:

  ```
  # For HTTP/JSON-RPC requests
  headers = [
    {"X-GraphOS-RPC-Secret", "your_secret_here"},
    {"Content-Type", "application/json"}
  ]

  # For gRPC requests
  metadata = [{"x-graph-os-rpc-secret", "your_secret_here"}]
  ```

  ## Module Structure

  - `GraphOS.Protocol.Auth` - Main authentication module (this module)
  - `GraphOS.Protocol.Auth.Secret` - Secret management and validation
  - `GraphOS.Protocol.Auth.Plug` - Plug middleware for authentication
  """

  alias GraphOS.Protocol.Auth.Secret

  @doc """
  Validates a provided secret against the configured secret.

  This is a convenience wrapper around `GraphOS.Protocol.Auth.Secret.validate/1`.

  ## Parameters

  - `provided_secret` - The secret to validate

  ## Returns

  - `:ok` if the secret is valid or not required
  - `{:error, reason}` if the secret is invalid or missing when required

  ## Examples

  ```elixir
  iex> GraphOS.Protocol.Auth.validate_secret("correct_secret")
  :ok

  iex> GraphOS.Protocol.Auth.validate_secret("wrong_secret")
  {:error, :invalid_secret}

  iex> GraphOS.Protocol.Auth.validate_secret(nil)
  {:error, :missing_secret}
  ```
  """
  @spec validate_secret(String.t() | nil) :: :ok | {:error, atom()}
  def validate_secret(provided_secret) do
    Secret.validate(provided_secret)
  end

  @doc """
  Returns the configured RPC secret.

  This is a convenience wrapper around `GraphOS.Protocol.Auth.Secret.get_secret/0`.

  ## Returns

  - The configured secret string
  - `nil` if no secret is configured

  ## Examples

  ```elixir
  iex> GraphOS.Protocol.Auth.get_secret()
  "configured_secret"
  ```
  """
  @spec get_secret() :: String.t() | nil
  def get_secret do
    Secret.get_secret()
  end

  @doc """
  Checks if authentication is required.

  This is a convenience wrapper around `GraphOS.Protocol.Auth.Secret.required?/0`.

  ## Returns

  - `true` if authentication is required
  - `false` if authentication is optional

  ## Examples

  ```elixir
  iex> GraphOS.Protocol.Auth.required?()
  true
  ```
  """
  @spec required?() :: boolean()
  def required? do
    Secret.required?()
  end
end
