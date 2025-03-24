defmodule GraphOS.Store.EdgeTest do
  use ExUnit.Case

  alias GraphOS.Store.Edge

  test "creates a new edge" do
    edge =
      Edge.new(%{
        id: "edge1",
        source: "node1",
        target: "node2",
        type: "test",
        data: %{weight: 5}
      })

    assert edge.id == "edge1"
    assert edge.source == "node1"
    assert edge.target == "node2"
    assert edge.type == "test"
    assert edge.data.weight == 5
    assert is_map(edge.metadata)
  end
end
