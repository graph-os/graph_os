defmodule GraphOS.MCP.HTTP.RouterPlug do
  @moduledoc """
  A plug for mounting MCP HTTP endpoints in a Phoenix router.

  ## Usage

  In your Phoenix router:

  ```elixir
  scope "/mcp" do
    pipe_through :api
    forward "/", GraphOS.MCP.HTTP.RouterPlug
  end
  ```
  """

  alias GraphOS.MCP.HTTP.Endpoint

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    Endpoint.call(conn, [])
  end
end
