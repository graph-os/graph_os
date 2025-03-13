defmodule JSONRPC.V2.Notification do
  @moduledoc false

  @jsonrpc_version "2.0"

  @type id :: String.t() | non_neg_integer()
  @type method :: String.t()
  @type params :: map()
  @type schema :: atom()

  @type t :: %__MODULE__{
          jsonrpc: String.t(),
          method: method(),
          params: params() | nil,
          __schema__: schema()
        }

  @required_keys [:jsonrpc, :id, :method, :__schema__]
  @optional_keys [:params]
  @keys @required_keys ++ @optional_keys

  @enforce_keys @required_keys
  defstruct @keys

  def decode(payload, schema \\ :jsonrpc_request) do
    %__MODULE__{
      jsonrpc: @jsonrpc_version,
      id: Keyword.get(payload, :id),
      method: Keyword.get(payload, :method),
      params: Keyword.get(payload, :params),
      __schema__: schema
    }
  end

  def encode(%__MODULE__{jsonrpc: jsonrpc, method: method, params: params}) do
    %{
      "jsonrpc" => jsonrpc,
      "method" => method,
      "params" => params
    }
  end

  def schema do
    %{
      "type" => "object",
      "required" => ["jsonrpc", "method"],
      "properties" => %{
        "jsonrpc" => %{"enum" => [@jsonrpc_version]},
        "method" => %{"type" => "string"},
        "params" => %{"type" => "object"}
      },
      "additionalProperties" => false
    }
  end
end
