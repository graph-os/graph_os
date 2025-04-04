defmodule GraphOS.Protocol.Auth.Secret do
  use Boundary, deps: [GraphOS.Protocol.Auth]

  @moduledoc """
  Secret-based authentication for GraphOS protocol endpoints.

  This module manages the RPC secret used for authenticating clients connecting
  to GraphOS protocol services (gRPC, JSON-RPC). It's primarily used to restrict
  access to the protocol from different users on the same machine.

  ## Configuration

  The secret is configured in environment-specific config files:

  ```elixir
  # In config/dev.exs
  config :graph_os_protocol, :auth,
    rpc_secret: "dev_only_secret_key",
    required: true # Make authentication mandatory, default true
  ```

  For production environments, you should set the secret via environment variables:

  ```elixir
  # In config/runtime.exs or config/prod.exs
  config :graph_os_protocol, :auth,
    rpc_secret: System.get_env("GRAPH_OS_RPC_SECRET"),
    required: true
  ```

  ## Usage

  When implementing a client:

  ```
  # Set as an HTTP header
  X-GraphOS-RPC-Secret: your_secret_here

  # Or as a gRPC metadata field
  metadata = [{"x-graphos-rpc-secret", "your_secret_here"}]
  ```
  """

  @doc """
  Returns the configured RPC secret.

  ## Returns

  - The configured secret string
  - `nil` if no secret is configured
  """
  @spec get_secret() :: String.t() | nil
  def get_secret do
    case Application.get_env(:graph_os_protocol, :auth) do
      nil -> nil
      auth_config -> Keyword.get(auth_config, :rpc_secret)
    end
  end

  @doc """
  Checks if authentication is required.

  By default, authentication is required if a secret is configured.

  ## Returns

  - `true` if authentication is required
  - `false` if authentication is optional
  """
  @spec required?() :: boolean()
  def required? do
    case Application.get_env(:graph_os_protocol, :auth) do
      nil -> false
      auth_config -> Keyword.get(auth_config, :required, true)
    end
  end

  @doc """
  Validates a provided secret against the configured secret.

  ## Parameters

  - `provided_secret` - The secret to validate

  ## Returns

  - `:ok` if the secret is valid or not required
  - `{:error, reason}` if the secret is invalid or missing when required
  """
  @spec validate(String.t() | nil) :: :ok | {:error, atom()}
  def validate(provided_secret) do
    configured_secret = get_secret()

    cond do
      # If authentication is not required and no secret was provided
      not required?() and is_nil(provided_secret) ->
        :ok

      # If no secret is configured and authentication is not required
      is_nil(configured_secret) and not required?() ->
        :ok

      # If authentication is required but no secret was provided
      required?() and is_nil(provided_secret) ->
        {:error, :missing_secret}

      # If secret is provided and matches configured secret
      is_binary(provided_secret) and is_binary(configured_secret) and
          secure_compare(provided_secret, configured_secret) ->
        :ok

      # Any other case is unauthorized
      true ->
        {:error, :invalid_secret}
    end
  end

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    import Bitwise

    Enum.reduce(0..(byte_size(a) - 1), 0, fn i, acc ->
      # Compare each byte and OR the result into the accumulator
      # If any bytes differ, the accumulator will be non-zero
      acc ||| if(binary_part(a, i, 1) == binary_part(b, i, 1), do: 0, else: 1)
    end) == 0
  end

  defp secure_compare(_a, _b), do: false
end
