defmodule GraphOS.Entity.Protocol.Enumerable do
  @moduledoc """
  Implementation of the Enumerable protocol for GraphOS entity types.
  """

  # Implement Enumerable for GraphOS.Entity.Graph
  defimpl Enumerable, for: GraphOS.Entity.Graph do
    def count(_graph), do: {:error, __MODULE__}

    def member?(_graph, _element), do: {:error, __MODULE__}

    def slice(_graph), do: {:error, __MODULE__}

    def reduce(graph, acc, fun) do
      # Convert Graph to a map for enumeration
      graph
      |> Map.from_struct()
      |> Enum.reduce(acc, fun)
    end
  end

  # Implement Enumerable for GraphOS.Entity.Node if needed
  defimpl Enumerable, for: GraphOS.Entity.Node do
    def count(_node), do: {:error, __MODULE__}

    def member?(_node, _element), do: {:error, __MODULE__}

    def slice(_node), do: {:error, __MODULE__}

    def reduce(node, acc, fun) do
      # Convert Node to a map for enumeration
      node
      |> Map.from_struct()
      |> Enum.reduce(acc, fun)
    end
  end

  # Implement Enumerable for GraphOS.Entity.Edge if needed
  defimpl Enumerable, for: GraphOS.Entity.Edge do
    def count(_edge), do: {:error, __MODULE__}

    def member?(_edge, _element), do: {:error, __MODULE__}

    def slice(_edge), do: {:error, __MODULE__}

    def reduce(edge, acc, fun) do
      # Convert Edge to a map for enumeration
      edge
      |> Map.from_struct()
      |> Enum.reduce(acc, fun)
    end
  end

  # Implement Enumerable for GraphOS.Entity.Metadata
  defimpl Enumerable, for: GraphOS.Entity.Metadata do
    def count(_metadata), do: {:error, __MODULE__}

    def member?(_metadata, _element), do: {:error, __MODULE__}

    def slice(_metadata), do: {:error, __MODULE__}

    def reduce(metadata, acc, fun) do
      # Convert Metadata to a map for enumeration
      metadata
      |> Map.from_struct()
      |> Enum.reduce(acc, fun)
    end
  end
end
