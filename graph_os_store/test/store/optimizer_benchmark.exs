defmodule GraphOS.Store.OptimizerBenchmark do
  @moduledoc """
  Benchmark tests for GraphOS performance optimizations.
  
  Run with:
  mix run test/store/optimizer_benchmark.exs
  """
  
  alias GraphOS.Store
  alias GraphOS.Entity.Node
  alias GraphOS.Entity.Edge
  
  # Benchmark configuration
  @node_count 10_000
  @edge_count 50_000
  @edge_types ["friend", "colleague", "family", "follows"]
  
  def run do
    IO.puts "\n=============================================\n"
    IO.puts "GraphOS Performance Optimization Benchmark"
    IO.puts "=============================================\n"
    
    # Set up test stores
    IO.puts "Setting up test environment..."
    
    # Standard store (no optimizations)
    standard_store = "standard_benchmark_#{:rand.uniform(10000)}"
    {:ok, _} = Store.start_link(name: standard_store, adapter: GraphOS.Store.Adapter.ETS)
    
    # Optimized store (with all optimizations)
    optimized_store = "optimized_benchmark_#{:rand.uniform(10000)}"
    {:ok, _} = Store.start_link(name: optimized_store, adapter: GraphOS.Store.Adapter.ETS, compressed: true)
    Process.put(:current_algorithm_store, optimized_store)
    
    # Generate identical test data
    IO.puts "Generating #{@node_count} nodes and #{@edge_count} edges..."
    
    # Create nodes
    {nodes, node_time} = :timer.tc(fn ->
      for i <- 1..@node_count do
        node = Node.new(%{
          id: "node_#{i}",
          data: %{
            "name" => "Test Node #{i}",
            "value" => :rand.uniform(1000),
            "created_at" => System.system_time(:second)
          }
        })
        Store.insert(standard_store, Node, node)
        Store.insert(optimized_store, Node, node)
        node
      end
    end)
    
    # Create edges with different types
    {_edges, edge_time} = :timer.tc(fn ->
      for i <- 1..@edge_count do
        source = Enum.at(nodes, :rand.uniform(@node_count) - 1)
        target = Enum.at(nodes, :rand.uniform(@node_count) - 1)
        edge_type = Enum.at(@edge_types, rem(i, length(@edge_types)))
        
        edge = Edge.new(%{
          id: "edge_#{i}",
          source: source.id,
          target: target.id,
          data: %{
            "type" => edge_type,
            "weight" => :rand.uniform(100),
            "created_at" => System.system_time(:second)
          }
        })
        
        Store.insert(standard_store, Edge, edge)
        Store.insert(optimized_store, Edge, edge)
        edge
      end
    end)
    
    IO.puts "Created #{@node_count} nodes in #{node_time / 1_000_000}s"
    IO.puts "Created #{@edge_count} edges in #{edge_time / 1_000_000}s"
    
    # Select test nodes
    test_node = Enum.at(nodes, :rand.uniform(div(@node_count, 10)))
    
    # Benchmark 1: Edge Type Filtering
    IO.puts "\n#1: Edge Type Filtering"
    IO.puts "-------------------"
    
    # Traditional filtering (without index)
    {standard_time, standard_results} = :timer.tc(fn ->
      {:ok, all_edges} = Store.list(standard_store, Edge)
      Enum.filter(all_edges, fn edge -> 
        Map.get(edge.data, "type") == "friend"
      end)
    end)
    
    # Optimized filtering (with type index)
    {optimized_time, optimized_results} = :timer.tc(fn ->
      {:ok, typed_edges} = GraphOS.Store.Adapter.ETS.get_edges_by_type(optimized_store, "friend")
      typed_edges
    end)
    
    IO.puts "Standard filtering: #{standard_time / 1_000}ms (#{length(standard_results)} results)"
    IO.puts "Optimized filtering: #{optimized_time / 1_000}ms (#{length(optimized_results)} results)"
    IO.puts "Speedup: #{standard_time / optimized_time}x"
    
    # Benchmark 2: Filtered Traversal
    IO.puts "\n#2: Edge Type + Source Node Filtering"
    IO.puts "--------------------------------"
    
    # Traditional traversal
    {standard_time, standard_results} = :timer.tc(fn ->
      {:ok, all_edges} = Store.list(standard_store, Edge)
      Enum.filter(all_edges, fn edge -> 
        Map.get(edge.data, "type") == "friend" && edge.source == test_node.id
      end)
    end)
    
    # Optimized traversal
    {optimized_time, optimized_results} = :timer.tc(fn ->
      {:ok, outgoing_friends} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type(optimized_store, test_node.id, "friend")
      outgoing_friends
    end)
    
    IO.puts "Standard traversal: #{standard_time / 1_000}ms (#{length(standard_results)} results)"
    IO.puts "Optimized traversal: #{optimized_time / 1_000}ms (#{length(optimized_results)} results)"
    IO.puts "Speedup: #{standard_time / optimized_time}x"
    
    # Benchmark 3: Path Finding with Cache
    IO.puts "\n#3: Path Finding Performance"
    IO.puts "-------------------------"
    
    # First path find (uncached)
    source_node = Enum.at(nodes, :rand.uniform(div(@node_count, 2)))
    target_node = Enum.at(nodes, div(@node_count, 2) + :rand.uniform(div(@node_count, 2)))
    
    # Warm up the cache
    {:ok, _path, _weight} = GraphOS.Store.Algorithm.ShortestPath.execute(
      source_node.id, target_node.id, 
      [store: optimized_store, use_cache: true]
    )
    
    # Uncached path find
    {uncached_time, _} = :timer.tc(fn ->
      GraphOS.Store.Algorithm.ShortestPath.execute(
        source_node.id, target_node.id, 
        [store: optimized_store, use_cache: false]
      )
    end)
    
    # Cached path find
    {cached_time, _} = :timer.tc(fn ->
      GraphOS.Store.Algorithm.ShortestPath.execute(
        source_node.id, target_node.id, 
        [store: optimized_store, use_cache: true]
      )
    end)
    
    IO.puts "Uncached path finding: #{uncached_time / 1_000}ms"
    IO.puts "Cached path finding: #{cached_time / 1_000}ms"
    IO.puts "Speedup: #{uncached_time / cached_time}x"
    
    # Benchmark 4: Memory Usage 
    IO.puts "\n#4: Memory Efficiency"
    IO.puts "-------------------"
    
    standard_memory = measure_memory_usage(standard_store)
    optimized_memory = measure_memory_usage(optimized_store)
    
    IO.puts "Standard store memory: #{standard_memory} bytes"
    IO.puts "Optimized store memory: #{optimized_memory} bytes"
    IO.puts "Memory savings: #{(1 - optimized_memory / standard_memory) * 100}%"
    
    # Clean up
    Store.stop(standard_store)
    Store.stop(optimized_store)
    
    IO.puts "\nBenchmark complete."
  end
  
  # Helper to measure memory usage of a store
  defp measure_memory_usage(store_name) do
    node_table = String.to_atom("#{store_name}_nodes")
    edge_table = String.to_atom("#{store_name}_edges")
    
    node_memory = :ets.info(node_table, :memory) * :erlang.system_info(:wordsize)
    edge_memory = :ets.info(edge_table, :memory) * :erlang.system_info(:wordsize)
    
    node_memory + edge_memory
  end
end

# Run the benchmark
GraphOS.Store.OptimizerBenchmark.run()
