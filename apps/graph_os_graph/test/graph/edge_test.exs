defmodule GraphOS.Graph.EdgeTest do
  use ExUnit.Case

  alias GraphOS.Graph.{Edge, Meta}

  test "creates a new edge" do
    edge = Edge.new("node1", "node2", [id: "edge1", key: "test", weight: 5])

    assert edge.id == "edge1"
    assert edge.source == "node1"
    assert edge.target == "node2"
    assert edge.key == "test"
    assert edge.weight == 5
    assert %Meta{} = edge.meta
  end
end
