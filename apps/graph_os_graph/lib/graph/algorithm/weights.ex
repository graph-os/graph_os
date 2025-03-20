defmodule GraphOS.GraphContext.Algorithm.Weights do
  @moduledoc """
  Utility functions for handling edge weights in graph algorithms.
  """

  @doc """
  Gets the weight of an edge.

  If the edge is nil, returns the default_weight.
  If the edge has a weight, returns that weight.
  """
  @spec get_edge_weight(GraphOS.GraphContext.Edge.t() | nil, any(), number() | nil) :: number()
  def get_edge_weight(nil, _property_name, default_weight), do: default_weight
  def get_edge_weight(edge, _property_name, default_weight) do
    case edge.weight do
      nil -> default_weight
      weight -> weight
    end
  end

  @doc """
  Normalizes weights in a graph to a range between 0 and 1.

  ## Examples

      iex> weights = %{"edge1" => 10, "edge2" => 20, "edge3" => 30}
      iex> GraphOS.GraphContext.Algorithm.Weights.normalize_weights(weights)
      %{"edge1" => 0.0, "edge2" => 0.5, "edge3" => 1.0}
  """
  @spec normalize_weights(map()) :: map()
  def normalize_weights(weights) when map_size(weights) == 0, do: %{}
  def normalize_weights(weights) do
    {min_weight, max_weight} = find_min_max(weights)

    # If all weights are the same, return a map with all zeros
    if max_weight == min_weight do
      Enum.map(weights, fn {k, _v} -> {k, 0.0} end) |> Map.new()
    else
      # Otherwise normalize to [0,1]
      range = max_weight - min_weight
      Enum.map(weights, fn {k, v} -> {k, (v - min_weight) / range} end) |> Map.new()
    end
  end

  @doc """
  Inverts weights for algorithms that prefer lower weights.

  ## Options

  * `:reciprocal` - Inverts weights using the formula 1/weight (default)
  * `:subtract` - Inverts weights by subtracting from the max value

  ## Examples

      iex> weights = %{"edge1" => 1, "edge2" => 2, "edge3" => 4}
      iex> GraphOS.GraphContext.Algorithm.Weights.invert_weights(weights, :reciprocal)
      %{"edge1" => 1.0, "edge2" => 0.5, "edge3" => 0.25}

      iex> weights = %{"edge1" => 1, "edge2" => 2, "edge3" => 4}
      iex> GraphOS.GraphContext.Algorithm.Weights.invert_weights(weights, :subtract)
      %{"edge1" => 3.0, "edge2" => 2.0, "edge3" => 0.0}
  """
  @spec invert_weights(map(), atom(), number() | nil) :: map()
  def invert_weights(weights, method \\ :reciprocal, max_value \\ nil)

  def invert_weights(weights, :reciprocal, _max_value) do
    {_min, max} = find_min_max(weights)

    Enum.map(weights, fn {k, v} ->
      cond do
        v <= 0 -> {k, max}
        true -> {k, 1.0 / v}
      end
    end)
    |> Map.new()
  end

  def invert_weights(weights, :subtract, nil) do
    {_min, max} = find_min_max(weights)
    invert_weights(weights, :subtract, max)
  end

  def invert_weights(weights, :subtract, max_value) do
    Enum.map(weights, fn {k, v} -> {k, max_value - v} end)
    |> Map.new()
  end

  # Helper function to find min and max values in a weight map
  defp find_min_max(weights) do
    values = Map.values(weights)
    {Enum.min(values), Enum.max(values)}
  end
end
