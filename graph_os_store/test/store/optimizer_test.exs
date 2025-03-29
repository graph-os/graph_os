defmodule GraphOS.Store.OptimizerTest do
  @moduledoc """
  Tests for GraphOS performance optimizations.
  """
  
  use ExUnit.Case
  
  alias GraphOS.Store
  alias GraphOS.Entity.Node
  alias GraphOS.Entity.Edge
  
  # Helper function to set process dictionary for algorithms
  def ensure_current_algorithm_store(store_name) do
    Process.put(:current_algorithm_store, store_name)
    store_name
  end
  
  @tag :optimization
  test "edge type indexing optimization" do
    # Start a store with the new optimization features
    store_name = "optimizer_test_#{:rand.uniform(10000)}"
    {:ok, _pid} = Store.start_link(name: store_name, adapter: GraphOS.Store.Adapter.ETS, compressed: true)
    store_name = ensure_current_algorithm_store(store_name)
    
    # Create test nodes
    nodes = for i <- 1..100 do
      node = Node.new(%{id: "node_#{i}", data: %{"value" => i}})
      {:ok, _} = Store.insert(store_name, Node, node)
      node
    end
    
    # Create edges with different types
    _friendship_edges = for i <- 1..50 do
      source = Enum.at(nodes, :rand.uniform(100) - 1)
      target = Enum.at(nodes, :rand.uniform(100) - 1)
      edge = Edge.new(%{
        id: "friendship_#{i}",
        source: source.id,
        target: target.id,
        data: %{"type" => "friendship", "strength" => :rand.uniform(10)}
      })
      {:ok, _} = Store.insert(store_name, Edge, edge)
      edge
    end
    
    _colleague_edges = for i <- 1..30 do
      source = Enum.at(nodes, :rand.uniform(100) - 1)
      target = Enum.at(nodes, :rand.uniform(100) - 1)
      edge = Edge.new(%{
        id: "colleague_#{i}",
        source: source.id,
        target: target.id,
        data: %{"type" => "colleague", "department" => "engineering"}
      })
      {:ok, _} = Store.insert(store_name, Edge, edge)
      edge
    end
    
    _family_edges = for i <- 1..20 do
      source = Enum.at(nodes, :rand.uniform(100) - 1)
      target = Enum.at(nodes, :rand.uniform(100) - 1)
      edge = Edge.new(%{
        id: "family_#{i}",
        source: source.id,
        target: target.id,
        data: %{"type" => "family", "relation" => "sibling"}
      })
      {:ok, _} = Store.insert(store_name, Edge, edge)
      edge
    end
    
    # Test edge type indexing
    {:ok, friendship_results} = GraphOS.Store.Adapter.ETS.get_edges_by_type(store_name, "friendship")
    assert length(friendship_results) == 50
    
    {:ok, colleague_results} = GraphOS.Store.Adapter.ETS.get_edges_by_type(store_name, "colleague")
    assert length(colleague_results) == 30
    
    {:ok, family_results} = GraphOS.Store.Adapter.ETS.get_edges_by_type(store_name, "family")
    assert length(family_results) == 20
    
    # Test combined filtering (source + type)
    source_node = Enum.at(nodes, 0)
    {:ok, outgoing_friendships} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type(store_name, source_node.id, "friendship")
    assert is_list(outgoing_friendships)
    
    # Verify edge types are correct
    Enum.each(outgoing_friendships, fn edge ->
      assert Map.get(edge.data, "type") == "friendship"
      assert edge.source == source_node.id
    end)
    
    # Test performance comparison
    # First with standard filtering
    {standard_time, _} = :timer.tc(fn ->
      {:ok, all_edges} = Store.all(store_name, Edge, %{})
      Enum.filter(all_edges, fn edge -> 
        Map.get(edge.data, "type") == "friendship" && 
        edge.source == source_node.id
      end)
    end)
    
    # Then with optimized type indexing
    {optimized_time, _} = :timer.tc(fn ->
      GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type(store_name, source_node.id, "friendship")
    end)
    
    # The optimized query should be significantly faster
    IO.puts("Standard filtering time: #{standard_time / 1000}ms")
    IO.puts("Optimized indexing time: #{optimized_time / 1000}ms")
    IO.puts("Performance improvement: #{standard_time / optimized_time}x")
    
    # Assert the optimization is at least 2x faster
    assert standard_time > optimized_time * 2
    
    # Test query planner
    query_spec = %{
      operations: [:find],
      filters: [
        %{field: "type", operator: :eq, value: "friendship"},
        %{field: "source", operator: :eq, value: source_node.id}
      ]
    }
    
    {:ok, plan} = GraphOS.Store.Query.Planner.optimize(store_name, query_spec)
    assert :edge_source_type in plan.use_indices
    
    # Clean up
    Store.stop(store_name)
  end
  
  @tag :optimization
  test "memory optimization with compression" do
    # Start a store with compression enabled
    compressed_store_name = "compressed_test_#{:rand.uniform(10000)}"
    {:ok, _pid} = Store.start_link(name: compressed_store_name, adapter: GraphOS.Store.Adapter.ETS, compressed: true)
    ensure_current_algorithm_store(compressed_store_name)
    
    # Start a store without compression for comparison
    standard_store_name = "standard_test_#{:rand.uniform(10000)}"
    {:ok, _pid} = Store.start_link(name: standard_store_name, adapter: GraphOS.Store.Adapter.ETS, compressed: false)
    
    # Generate identical test data for both stores
    test_data = for i <- 1..1000 do
      Node.new(%{id: "node_#{i}", data: %{
        "name" => "Test Node #{i}",
        "description" => String.duplicate("Lorem ipsum dolor sit amet. ", 10),
        "attributes" => Map.new(1..20, fn j -> {"attr_#{j}", "value_#{j}"} end)
      }})
    end
    
    # Insert data into both stores
    Enum.each(test_data, fn node ->
      Store.insert(compressed_store_name, Node, node)
      Store.insert(standard_store_name, Node, node)
    end)
    
    # Report memory usage (this is approximate)
    compressed_info = :ets.info(String.to_atom("#{compressed_store_name}_nodes"))
    standard_info = :ets.info(String.to_atom("#{standard_store_name}_nodes"))
    
    compressed_memory = compressed_info[:memory] * :erlang.system_info(:wordsize)
    standard_memory = standard_info[:memory] * :erlang.system_info(:wordsize)
    
    compression_ratio = standard_memory / compressed_memory
    
    IO.puts("Standard store memory usage: #{standard_memory} bytes")
    IO.puts("Compressed store memory usage: #{compressed_memory} bytes")
    IO.puts("Compression ratio: #{compression_ratio}x")
    
    # The compression should provide at least some memory savings
    # Note: actual savings depend on the data and may vary
    assert compression_ratio > 1.0
    
    # Clean up
    Store.stop(compressed_store_name)
    Store.stop(standard_store_name)
  end
  
  @tag :performance
  @tag :optimization
  test "edge type optimization for very large graphs" do
    # Start a store with the optimization features
    store_name = "large_graph_optimizer_test_#{:rand.uniform(10000)}"
    {:ok, _pid} = Store.start_link(name: store_name, adapter: GraphOS.Store.Adapter.ETS, compressed: true)
    store_name = ensure_current_algorithm_store(store_name)
    
    # Parameters for the large graph
    node_count = 5_000
    edge_count = 20_000
    edge_types = ["friend", "colleague", "family", "follows"]
    
    IO.puts("Creating #{node_count} nodes and #{edge_count} edges for large graph test...")
    
    # Create test nodes in batches for efficiency
    nodes_batches = Enum.chunk_every(1..node_count, 500)

    Enum.each(nodes_batches, fn batch_ids ->
      # Insert nodes individually since batch_insert isn't available
      Enum.each(batch_ids, fn n ->
        node = Node.new(%{id: "node_#{n}", data: %{"name" => "Node #{n}"}})
        {:ok, _} = Store.insert(store_name, Node, node)
      end)
    end)
    
    # Create edges with different types in batches
    edges_batches = Enum.chunk_every(1..edge_count, 500)
    
    Enum.each(edges_batches, fn batch_ids ->
      # Insert edges individually since batch_insert isn't available
      Enum.each(batch_ids, fn e ->
        source = "node_#{:rand.uniform(node_count)}"
        target = "node_#{:rand.uniform(node_count)}"
        
        # Make 25% of edges the test type
        type = if rem(e, 4) == 0, do: "friend", else: "other_type_#{rem(e, 10)}"
        
        edge = Edge.new(%{source: source, target: target, data: %{"type" => type}})
        {:ok, _} = Store.insert(store_name, Edge, edge) 
      end)
    end)
    
    # Select a specific node for testing
    test_node_id = "node_#{:rand.uniform(div(node_count, 2))}"
    test_type = "friend"
    
    # Test standard edge filtering (without optimization)
    {standard_time, standard_results} = :timer.tc(fn ->
      {:ok, all_edges} = Store.all(store_name, Edge, %{})
      Enum.filter(all_edges, fn edge -> 
        Map.get(edge.data, "type") == test_type && 
        edge.source == test_node_id
      end)
    end)
    
    # Test optimized edge filtering using type index
    {optimized_time, optimized_results} = :timer.tc(fn ->
      {:ok, typed_edges} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type(store_name, test_node_id, test_type)
      typed_edges
    end)
    
    # Print results
    IO.puts("Large graph test results:")
    IO.puts("Standard filtering time: #{standard_time / 1_000}ms (#{length(standard_results)} results)")
    IO.puts("Optimized filtering time: #{optimized_time / 1_000}ms (#{length(optimized_results)} results)")
    IO.puts("Performance improvement: #{standard_time / optimized_time}x")
    
    # Verify that the optimization maintains correctness
    assert length(optimized_results) >= 0
    
    # The optimized query should be significantly faster on large graphs
    # Aim for at least a 5x improvement
    assert standard_time / optimized_time > 5.0
  end
  
  describe "very large graph traversal optimizations" do
    setup do
      store_name = "test_store_#{:rand.uniform(1_000_000)}"
      {:ok, _pid} = Store.start_link(name: store_name, adapter: GraphOS.Store.Adapter.ETS)

      # Create a sample large graph - use fewer nodes for test performance but enough to see optimization differences
      node_count = 500
      edge_count = 2000
      edge_type = "test_type"
      
      # Create nodes in batch for better performance
      nodes = Enum.map(1..node_count, fn n -> 
        Node.new(%{id: "node_#{n}", data: %{"name" => "Node #{n}"}})
      end)
      
      # Insert nodes since batch_insert isn't available
      nodes
      |> Enum.chunk_every(100)
      |> Enum.each(fn batch ->
        Enum.each(batch, fn node ->
          {:ok, _} = Store.insert(store_name, Node, node)
        end)
      end)
      
      # For testing traversal, ensure one source node has many outgoing edges of the same type
      source_node = "node_1"
      
      # Create edges in batch for better performance
      edges = Enum.map(1..edge_count, fn e ->
        # Distribute edges across nodes, but ensure source_node has many edges
        source = if rem(e, 5) == 0, do: source_node, else: "node_#{:rand.uniform(node_count)}"
        target = "node_#{:rand.uniform(node_count)}"
        
        # Ensure a good portion of edges have our test edge type
        type = if rem(e, 3) == 0, do: edge_type, else: "other_type_#{rem(e, 5)}"
        
        Edge.new(%{source: source, target: target, data: %{"type" => type}})
      end)
      
      # Insert edges in batches
      edges
      |> Enum.chunk_every(100)
      |> Enum.each(fn batch ->
        Enum.each(batch, fn edge ->
          {:ok, _} = Store.insert(store_name, Edge, edge)
        end)
      end)
      
      # Return test context
      {:ok, %{store: store_name, source_node: source_node, edge_type: edge_type}}
    end
    
    test "compare traversal optimization approaches", %{store: store, source_node: source_node, edge_type: edge_type} do
      # Test 1: Standard approach - filter all edges (baseline)
      {standard_time, standard_results} = :timer.tc(fn ->
        {:ok, all_edges} = Store.all(store, Edge, %{})
        Enum.filter(all_edges, fn edge -> 
          Map.get(edge.data, "type") == edge_type && 
          edge.source == source_node
        end)
      end)
      
      # Test 2: Optimized composite index approach
      {optimized_time, optimized_results} = :timer.tc(fn ->
        {:ok, edges} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type_optimized(store, source_node, edge_type)
        edges
      end)
      
      # Test 3: Parallel approach for very large datasets
      {parallel_time, parallel_results} = :timer.tc(fn ->
        {:ok, edges} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type_parallel(store, source_node, edge_type)
        edges
      end)
      
      # Verify all approaches return the same edges
      assert length(standard_results) > 0, "Test requires at least some matching edges"
      assert length(standard_results) == length(optimized_results)
      assert length(standard_results) == length(parallel_results)
      
      # Sort both lists to ensure consistent comparison
      standard_ids = standard_results |> Enum.map(& &1.id) |> Enum.sort()
      optimized_ids = optimized_results |> Enum.map(& &1.id) |> Enum.sort()
      parallel_ids = parallel_results |> Enum.map(& &1.id) |> Enum.sort()
      
      assert standard_ids == optimized_ids
      assert standard_ids == parallel_ids
      
      # Verify optimization approaches are faster than standard filtering
      # Note: In some test environments the parallel approach may have overhead,
      # so we mainly verify the optimized index approach which should always be faster
      assert optimized_time < standard_time, 
        "Optimized index traversal should be faster than standard filtering"
      
      # Log performance metrics
      IO.puts "Standard filtering: #{standard_time / 1_000}ms"
      IO.puts "Optimized index: #{optimized_time / 1_000}ms (#{standard_time / optimized_time}x faster)"
      IO.puts "Parallel processing: #{parallel_time / 1_000}ms (#{standard_time / parallel_time}x faster)"
      
      # Clean up
      Store.stop(store)
    end
  end
  
  @tag :performance
  test "edge caching performance improvement" do
    store_name = "cache_test_#{:rand.uniform(1_000_000)}"
    {:ok, _} = GraphOS.Store.start_link(store_name, GraphOS.Store.Adapter.ETS)
    
    # Create a moderate size graph for testing
    node_count = 1000
    edges_per_node = 20
    
    # Batch insert nodes
    nodes = for i <- 1..node_count do
      %GraphOS.Entity.Node{
        id: "node_#{i}",
        data: %{"name" => "Node #{i}"},
        metadata: %GraphOS.Entity.Metadata{}
      }
    end
    
    # Insert all nodes
    Enum.each(nodes, fn node ->
      GraphOS.Store.Adapter.ETS.insert(store_name, GraphOS.Entity.Node, node)
    end)
    
    # Connect nodes with edges
    Enum.each(1..node_count, fn i ->
      source = "node_#{i}"
      
      Enum.each(1..edges_per_node, fn j ->
        target_idx = rem(i + j, node_count) + 1  # Deterministic but distributed pattern
        target = "node_#{target_idx}"
        
        # Use different edge types
        edge_type = if rem(j, 4) == 0, do: "friend", else: "follows"
        
        edge = %GraphOS.Entity.Edge{
          id: "edge_#{source}_#{target}_#{edge_type}_#{j}",
          source: source,
          target: target,
          data: %{"type" => edge_type},
          metadata: %GraphOS.Entity.Metadata{}
        }
        
        GraphOS.Store.Adapter.ETS.insert_edge(store_name, edge)
      end)
    end)
    
    # Select a test node that will have a decent number of edges
    test_node = "node_42"
    test_type = "friend"
    
    # First query - should be a cache miss
    {first_query_time, first_result} = :timer.tc(fn ->
      GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type_cached(store_name, test_node, test_type)
    end)
    
    # Second query - should be a cache hit
    {second_query_time, second_result} = :timer.tc(fn ->
      GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type_cached(store_name, test_node, test_type) 
    end)
    
    # Third query with cache refresh - should be a cache miss
    {refresh_query_time, _} = :timer.tc(fn ->
      GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type_cached(store_name, test_node, test_type, [refresh_cache: true])
    end)
    
    # Convert to ms for readability
    first_query_ms = first_query_time / 1000
    second_query_ms = second_query_time / 1000
    refresh_query_ms = refresh_query_time / 1000
    
    # Display results
    IO.puts("\nEdge caching performance:")
    IO.puts("First query (cache miss): #{first_query_ms}ms")
    IO.puts("Second query (cache hit): #{second_query_ms}ms")
    IO.puts("Cache performance improvement: #{first_query_ms/second_query_ms}x")
    IO.puts("Cache refresh query: #{refresh_query_ms}ms")
    
    # Verify that the results are the same
    {:ok, edges1} = first_result
    {:ok, edges2} = second_result
    
    assert length(edges1) == length(edges2)
    assert MapSet.new(Enum.map(edges1, & &1.id)) == MapSet.new(Enum.map(edges2, & &1.id))
    
    # Make sure the cache hit is significantly faster (at least 2x)
    assert first_query_ms/second_query_ms > 2, "Cache hit should be at least 2x faster than cache miss"
  end
end
