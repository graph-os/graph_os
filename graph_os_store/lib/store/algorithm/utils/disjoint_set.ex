defmodule GraphOS.Store.Algorithm.Utils.DisjointSet do
  @moduledoc """
  Disjoint-set data structure (Union-Find) implementation.

  This module provides a disjoint-set (or union-find) data structure,
  used in various graph algorithms like finding connected components
  and minimum spanning trees.
  """

  @doc """
  Create a new disjoint set with the given elements.

  Each element is initially in its own set, with itself as the representative.

  ## Parameters

  - `elements` - A list of elements to be included in the disjoint set

  ## Returns

  - A map representing the disjoint set structure
  """
  def new(elements) do
    Enum.reduce(elements, %{}, fn elem, acc ->
      Map.put(acc, elem, elem)
    end)
  end

  @doc """
  Find the representative of the set containing the element.

  Uses path compression to optimize future lookups.

  ## Parameters

  - `set` - The disjoint set data structure
  - `element` - The element to find the representative for

  ## Returns

  - `{root, updated_set}` - The representative of the set and the updated disjoint set with path compression
  """
  def find(set, element) do
    parent = Map.get(set, element)
    if parent == element do
      {element, set}
    else
      {root, new_set} = find(set, parent)
      {root, Map.put(new_set, element, root)}
    end
  end

  @doc """
  Union the sets containing elements a and b.

  ## Parameters

  - `set` - The disjoint set data structure
  - `a` - The first element
  - `b` - The second element

  ## Returns

  - The updated disjoint set after the union operation
  """
  def union(set, a, b) do
    {root_a, set1} = find(set, a)
    {root_b, set2} = find(set1, b)

    if root_a != root_b do
      Map.put(set2, root_b, root_a)
    else
      set2
    end
  end

  @doc """
  Get all the disjoint sets as a map of representatives to their elements.

  ## Parameters

  - `set` - The disjoint set data structure

  ## Returns

  - A map where keys are set representatives and values are lists of elements in each set
  """
  def get_sets(set) do
    keys = Map.keys(set)

    # Find the root of each element
    roots = Enum.map(keys, fn key ->
      {root, _} = find(set, key)
      {key, root}
    end)

    # Group elements by their root
    Enum.reduce(roots, %{}, fn {elem, root}, acc ->
      Map.update(acc, root, [elem], fn elements -> [elem | elements] end)
    end)
  end
end
