defmodule GraphOS.Graph.Encoders.JasonEncoder do
  @moduledoc """
  Custom implementations of the Jason.Encoder protocol for GraphOS.Graph types.
  """

  # Explicitly implement the Jason.Encoder protocol for GraphOS.Graph.Meta
  defimpl Jason.Encoder, for: GraphOS.Graph.Meta do
    def encode(meta, opts) do
      meta
      |> Map.take([:created_at, :updated_at, :deleted_at, :version, :deleted])
      |> Jason.Encode.map(opts)
    end
  end
end
