defmodule GraphOS.Store.Algorithm.WeightsTest do
  use ExUnit.Case

  alias GraphOS.Store.{Edge}
  alias GraphOS.Store.Algorithm.Weights

  test "get_edge_weight/3" do
    # Create an edge with a weight
    edge = Edge.new(%{source: "source", target: "target", data: %{weight: 5}})
    assert Weights.get_edge_weight(edge, nil, nil) == 5

    # Test with nil edge
    assert Weights.get_edge_weight(nil, nil, 10) == 10

    # Test with default weight
    edge_no_weight = Edge.new(%{source: "source", target: "target", data: %{}})
    assert Weights.get_edge_weight(edge_no_weight, nil, 10) == 10
  end

  test "normalize_weights/1" do
    # Test with empty map
    assert Weights.normalize_weights(%{}) == %{}

    # Test with weights
    weights = %{"edge1" => 10, "edge2" => 20, "edge3" => 30}
    normalized = Weights.normalize_weights(weights)
    assert normalized["edge1"] == 0.0
    assert normalized["edge2"] == 0.5
    assert normalized["edge3"] == 1.0

    # Test with negative values
    weights = %{"edge1" => -10, "edge2" => 0, "edge3" => 10}
    normalized = Weights.normalize_weights(weights)
    assert normalized["edge1"] == 0.0
    assert normalized["edge2"] == 0.5
    assert normalized["edge3"] == 1.0

    # Test with all zero values
    weights = %{"edge1" => 0, "edge2" => 0, "edge3" => 0}
    normalized = Weights.normalize_weights(weights)
    assert normalized["edge1"] == 0.0
    assert normalized["edge2"] == 0.0
    assert normalized["edge3"] == 0.0
  end

  test "invert_weights/2" do
    # Test with reciprocal method
    weights = %{"edge1" => 1, "edge2" => 2, "edge3" => 4}
    inverted = Weights.invert_weights(weights, :reciprocal)
    assert inverted["edge1"] == 1.0
    assert inverted["edge2"] == 0.5
    assert inverted["edge3"] == 0.25

    # Test with subtract method
    weights = %{"edge1" => 1, "edge2" => 2, "edge3" => 4}
    inverted = Weights.invert_weights(weights, :subtract)
    assert inverted["edge1"] == 3.0
    assert inverted["edge2"] == 2.0
    assert inverted["edge3"] == 0.0

    # Test with zero values
    weights = %{"edge1" => 0, "edge2" => 2, "edge3" => 4}
    inverted = Weights.invert_weights(weights, :reciprocal)
    # Max value for zero
    assert inverted["edge1"] == 4.0
    assert inverted["edge2"] == 0.5
    assert inverted["edge3"] == 0.25

    # Test with custom max value
    weights = %{"edge1" => 1, "edge2" => 2, "edge3" => 4}
    inverted = Weights.invert_weights(weights, :subtract, 10)
    assert inverted["edge1"] == 9.0
    assert inverted["edge2"] == 8.0
    assert inverted["edge3"] == 6.0
  end
end
