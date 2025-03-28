defmodule GraphOS.StorePerformanceTest do
  @moduledoc """
  Performance tests for GraphOS.Store.
  
  These tests verify the performance of GraphOS.Store with large graphs
  and different algorithms. They are excluded from normal test runs due to
  their resource-intensive nature.
  
  To run only performance tests:
  ```
  mix test --only performance
  ```
  """
  
  use ExUnit.Case, async: false
  
  alias GraphOS.Store
  alias GraphOS.Store.Event
  alias GraphOS.Entity.Node
  alias GraphOS.Entity.Edge
  
  # Tag all tests as performance to exclude them from normal test runs
  @moduletag :performance
  
  # Size constants for various test scales - reduced sizes for faster tests
  @tiny_graph_size 100     # For quick iteration during debugging
  @small_graph_size 500    # For baseline algorithm tests 
  @medium_graph_size 1000  # For moderate load tests
  @large_graph_size 5000   # For stress tests
  
  # Adding helper function to ensure process dictionary is properly set for all tests
  def ensure_current_algorithm_store(store_name) do
    # Clear any previous setting and set the current value
    # This ensures that algorithms can find the store reference properly
    Process.put(:current_algorithm_store, store_name)
    store_name
  end
  
  setup do
    # Generate a unique name for each test store to avoid conflicts
    store_name = "performance_test_#{:rand.uniform(10000)}"
    
    # Create the store and set it as the current algorithm store in the process dictionary
    {:ok, _pid} = Store.start_link(name: store_name, adapter: GraphOS.Store.Adapter.ETS)
    store_name = ensure_current_algorithm_store(store_name)
    
    # Return the store name for use in tests
    {:ok, %{store_name: store_name}}
  end
  
  @doc """
  Measures execution time of a function.
  
  Returns {result, execution_time_ms}
  """
  def measure(function) do
    start = System.monotonic_time(:millisecond)
    result = function.()
    finish = System.monotonic_time(:millisecond)
    {result, finish - start}
  end
  
  @doc """
  Creates a random graph with nodes and edges.
  
  Options:
  - node_count: Number of nodes to create
  - edge_count: Number of edges to create
  - edge_types: List of edge types to use
  - node_types: List of node types to use
  - topology: :random, :barabasi_albert, :watts_strogatz, or :complete
  - id_prefix: Prefix for node IDs to ensure uniqueness
  
  Returns a list of node IDs.
  """
  def create_test_graph(store_name, opts \\ []) do
    node_count = Keyword.get(opts, :node_count, @small_graph_size)
    edge_factor = Keyword.get(opts, :edge_factor, 2)  # Average edges per node
    edge_count = Keyword.get(opts, :edge_count, node_count * edge_factor)
    edge_types = Keyword.get(opts, :edge_types, ["connects", "depends_on", "related_to", "references"])
    node_types = Keyword.get(opts, :node_types, ["person", "document", "location", "event", "concept"])
    topology = Keyword.get(opts, :topology, :random)
    # Add a unique prefix for this graph's nodes and edges
    id_prefix = Keyword.get(opts, :id_prefix, "g#{:erlang.system_time(:millisecond)}_")
    
    IO.puts("Creating test graph: #{node_count} nodes, #{edge_count} edges, topology: #{topology}")
    
    # Create nodes
    {nodes, node_time} = measure(fn ->
      Enum.map(1..node_count, fn i ->
        # Select node type based on position
        node_type = Enum.at(node_types, rem(i, length(node_types)))
        # Create properties that vary by node type
        properties = case node_type do
          "person" -> %{name: "Person #{i}", age: rem(i, 80) + 18}
          "document" -> %{title: "Document #{i}", size: i * 1024}
          "location" -> %{name: "Location #{i}", coordinates: {i / 100, i / 200}}
          "event" -> %{name: "Event #{i}", date: i * 86400}
          _ -> %{name: "Item #{i}", value: i}
        end
        
        node_id = "#{id_prefix}n#{i}"
        node = Node.new(%{id: node_id, type: node_type, data: properties})
        {:ok, _} = Store.insert(store_name, Node, node)
        node_id
      end)
    end)
    
    IO.puts("Created #{node_count} nodes in #{node_time}ms (#{node_time / node_count}ms per node)")
    
    # Create edges based on the specified topology
    {_, edge_time} = measure(fn ->
      case topology do
        :random -> create_random_edges(store_name, nodes, edge_count, edge_types, id_prefix)
        :barabasi_albert -> create_preferential_attachment_edges(store_name, nodes, edge_count, edge_types, id_prefix)
        :watts_strogatz -> create_small_world_edges(store_name, nodes, edge_count, edge_types, id_prefix)
        :complete -> create_complete_graph_edges(store_name, nodes, edge_types, id_prefix)
        _ -> create_random_edges(store_name, nodes, edge_count, edge_types, id_prefix)
      end
    end)
    
    IO.puts("Created edges in #{edge_time}ms")
    
    nodes
  end
  
  # Creates random edges between nodes
  defp create_random_edges(store_name, nodes, edge_count, edge_types, id_prefix) do
    Enum.each(1..edge_count, fn i ->
      source = Enum.random(nodes)
      target = Enum.random(nodes)
      
      # Avoid self-loops
      if source != target do
        edge_type = Enum.at(edge_types, rem(i, length(edge_types)))
        edge = Edge.new(%{
          id: "#{id_prefix}e#{i}",
          source: source,
          target: target,
          type: edge_type,
          data: %{weight: :rand.uniform(100)}
        })
        Store.insert(store_name, Edge, edge)
      end
    end)
  end
  
  # Creates a preferential attachment (Barabasi-Albert) graph - hubs and authorities
  defp create_preferential_attachment_edges(store_name, nodes, _edge_count, edge_types, id_prefix) do
    # Start with a small connected component
    initial_size = min(10, length(nodes))
    initial_nodes = Enum.take(nodes, initial_size)
    
    # Create initial connected component
    Enum.each(1..(initial_size-1), fn i ->
      source = Enum.at(initial_nodes, i-1)
      target = Enum.at(initial_nodes, i)
      edge_type = Enum.at(edge_types, rem(i, length(edge_types)))
      
      edge = Edge.new(%{
        id: "#{id_prefix}e_lattice_#{i}",
        source: source,
        target: target,
        type: edge_type,
        data: %{weight: :rand.uniform(100)}
      })
      Store.insert(store_name, Edge, edge)
    end)
    
    # Track node degrees to implement preferential attachment
    degrees = initial_nodes |> Enum.map(fn node -> {node, 1} end) |> Map.new()
    
    # Add remaining edges with preferential attachment
    remaining_nodes = Enum.drop(nodes, initial_size)
    
    {_final_degrees, _} = Enum.reduce(Enum.with_index(remaining_nodes), {degrees, initial_size}, fn {node, index}, {acc_degrees, edge_index} ->
      # Connect to m existing nodes with probability proportional to their degree
      target_count = :rand.uniform(5) + 1  # Connect to 2-6 existing nodes
      
      # Weight selection by degree (preferential attachment)
      targets = select_targets_by_weight(Map.keys(acc_degrees), Map.values(acc_degrees), target_count)
      
      # Create edges to selected targets
      new_degrees = Enum.reduce(targets, acc_degrees, fn target, degrees_acc ->
        edge_id = "#{id_prefix}e#{edge_index + index}"
        edge_type = Enum.at(edge_types, rem(edge_index + index, length(edge_types)))
        
        edge = Edge.new(%{
          id: edge_id,
          source: node,
          target: target,
          type: edge_type,
          data: %{weight: :rand.uniform(100)}
        })
        Store.insert(store_name, Edge, edge)
        
        # Update degrees
        Map.update(degrees_acc, node, 1, &(&1 + 1))
        |> Map.update(target, 1, &(&1 + 1))
      end)
      
      {new_degrees, edge_index + target_count}
    end)
  end
  
  # Creates a small-world (Watts-Strogatz) graph - high clustering with short paths
  defp create_small_world_edges(store_name, nodes, _edge_count, edge_types, id_prefix) do
    # Parameters for Watts-Strogatz model
    k = 4  # Reduced from 6 to 4 nearest neighbors for better performance
    beta = 0.2  # Rewiring probability
    
    node_count = length(nodes)
    node_array = Enum.to_list(nodes)
    
    # First create a ring lattice - much more efficiently
    Enum.each(0..(node_count-1), fn i ->
      node = Enum.at(node_array, i)
      
      # Connect to k/2 neighbors on each side
      Enum.each(1..div(k, 2), fn j ->
        # Calculate target indices (wrap around the ring)
        target_idx = rem(i + j, node_count)
        target = Enum.at(node_array, target_idx)
        
        edge_type = Enum.at(edge_types, rem(i*j, length(edge_types)))
        edge = Edge.new(%{
          id: "#{id_prefix}e_lattice_#{i}_#{j}",
          source: node,
          target: target,
          type: edge_type,
          data: %{weight: :rand.uniform(100)}
        })
        Store.insert(store_name, Edge, edge)
      end)
    end)
    
    # Avoid expensive rewiring for large graphs - do partial rewiring
    # Only rewire a subset of nodes when graph is large
    rewire_count = min(1000, node_count) 
    nodes_to_rewire = if node_count > 1000, do: Enum.take_random(0..(node_count-1), rewire_count), else: 0..(node_count-1)
    
    # Rewire edges with probability beta - more efficiently
    Enum.each(nodes_to_rewire, fn i ->
      node = Enum.at(node_array, i)
      
      # For each rewiring attempt, pre-compute available targets once
      available_targets = Enum.reject(node_array, fn n -> 
        n == node || 
        # Skip expensive find_index operation by using a different approach
        Enum.any?(1..div(k, 2), fn j -> 
          n == Enum.at(node_array, rem(i + j, node_count)) || 
          n == Enum.at(node_array, rem(i - j + node_count, node_count))
        end)
      end)
      
      # Do the rewiring if we have available targets
      if length(available_targets) > 0 do
        Enum.each(1..div(k, 2), fn j ->
          # Only rewire with probability beta
          if :rand.uniform() < beta do
            target = Enum.random(available_targets)
            
            edge_type = Enum.at(edge_types, rem(i*j, length(edge_types)))
            edge = Edge.new(%{
              id: "#{id_prefix}e_rewired_#{i}_#{j}",
              source: node,
              target: target,
              type: edge_type,
              data: %{weight: :rand.uniform(100)}
            })
            Store.insert(store_name, Edge, edge)
          end
        end)
      end
    end)
  end
  
  # Creates a complete graph where every node is connected to every other node
  defp create_complete_graph_edges(store_name, nodes, edge_types, id_prefix) do
    node_pairs = for source <- nodes, target <- nodes, source != target, do: {source, target}
    
    Enum.with_index(node_pairs)
    |> Enum.each(fn {{source, target}, i} ->
      edge_type = Enum.at(edge_types, rem(i, length(edge_types)))
      edge = Edge.new(%{
        id: "#{id_prefix}e_complete_#{i}",
        source: source,
        target: target,
        type: edge_type,
        data: %{weight: :rand.uniform(100)}
      })
      Store.insert(store_name, Edge, edge)
    end)
  end
  
  # Helper to select nodes with probability proportional to their weights
  defp select_targets_by_weight(nodes, weights, count) do
    # Calculate cumulative weights for efficient sampling
    _total_weight = Enum.sum(weights)  # Keep this calculation for clarity but prefix with _ since unused
    cum_weights = Enum.scan(weights, fn w, acc -> w + acc end)
    
    # Select count targets without replacement
    Enum.reduce(1..count, {[], nodes, cum_weights}, fn _, {selected, remaining_nodes, remaining_weights} ->
      if length(remaining_nodes) == 0 do
        {selected, remaining_nodes, remaining_weights} # No more nodes to select
      else
        # Select a node with probability proportional to weight
        r = :rand.uniform() * Enum.at(remaining_weights, -1)
        idx = Enum.find_index(remaining_weights, fn w -> w >= r end) || 0
        
        # Get the node at that index
        node = Enum.at(remaining_nodes, idx)
        
        # Remove selected node and update weights
        new_remaining = List.delete_at(remaining_nodes, idx)
        new_weights = 
          List.delete_at(remaining_weights, idx) 
          |> Enum.with_index() 
          |> Enum.map(fn {w, i} -> 
            if i < idx, do: w, else: w - Enum.at(weights, idx) 
          end)
        
        {[node | selected], new_remaining, new_weights}
      end
    end) 
    |> elem(0) # Return just the selected nodes
  end
  
  describe "large graph creation performance" do
    @tag timeout: 300_000 # Allow up to 5 minutes for this test
    test "can create a very large graph with complex topology", %{store_name: store_name} do
      # Create a graph with preferential attachment (scale-free)
      nodes = create_test_graph(store_name, [
        node_count: @medium_graph_size,
        edge_factor: 5,  # More edges per node for a denser graph
        topology: :barabasi_albert
      ])
      
      # Verify size
      assert length(nodes) == @medium_graph_size
      
      # Find how many edges were actually created - count using match pattern
      # Note: We're using match_object instead of list since list doesn't exist
      edge_count = :ets.info(String.to_atom("#{store_name}_edges"), :size)
      IO.puts("Verified graph with #{@medium_graph_size} nodes and #{edge_count} edges")
      
      # Basic statistics - measure retrieval times
      {_, node_get_time} = measure(fn ->
        Enum.each(1..100, fn _ ->
          random_node = Enum.random(nodes)
          {:ok, _} = Store.get(store_name, Node, random_node)
        end)
      end)
      
      IO.puts("Average node retrieval time: #{node_get_time / 100}ms")
    end
  end
  
  describe "algorithm performance on large graphs" do
    setup do
      {:ok, store} = Store.start_link(name: "performance_test_#{:rand.uniform(10000)}")
      
      # Get the store name for consistent reference
      store_name = GenServer.call(store, :get_name)
      
      # Initialize the algorithm store in process dictionary to ensure it's accessible
      # This is important to avoid store_not_found errors in complex tests
      Process.put(:current_algorithm_store, store_name)
      
      # Set up a very small test graph for quick iterations during debugging
      IO.puts("Setting up algorithm test graph - this may take a minute...")
      nodes = create_test_graph(store_name, [
        node_count: @tiny_graph_size,
        topology: :watts_strogatz
      ])
      
      {:ok, %{store_name: store_name, nodes: nodes}}
    end
    
    @tag timeout: 300_000 # Allow up to 5 minutes for this test
    test "bfs algorithm performance on large graphs", %{store_name: store_name} do
      # Explicitly set the current algorithm store in process dictionary
      store_name = ensure_current_algorithm_store(store_name)
      
      # Create a small world network for realistic pathfinding scenarios
      IO.puts("Setting up algorithm test graph - this may take a minute...")
      nodes = create_test_graph(store_name, [
        node_count: @small_graph_size,
        topology: :watts_strogatz
      ])
      
      # Choose a random node as the starting point
      start_node_id = Enum.random(nodes)
      
      # Run BFS with various depth limits to measure scaling
      depths = [5, 10, 20, 50]
      
      Enum.each(depths, fn depth ->
        {result, time} = measure(fn ->
          # Use Store.traverse with :bfs algorithm since direct module is not available
          Store.traverse(store_name, :bfs, {start_node_id, [max_depth: depth, direction: :outgoing]})
        end)
        
        # Extract visited nodes from the result
        visited_count = case result do
          {:ok, visited} -> length(visited)
          _ -> 0
        end
        
        IO.puts("BFS from a random node with max_depth #{depth} visited #{visited_count} nodes and took #{time}ms")
      end)
    end
    
    @tag timeout: 300_000 # Allow up to 5 minutes for this test
    test "page rank algorithm performance", %{store_name: store_name} do
      # Explicitly set the current algorithm store in process dictionary
      Process.put(:current_algorithm_store, store_name)
      
      # Create a preferential attachment network which is ideal for PageRank testing
      IO.puts("Setting up PageRank test graph - this may take a minute...")
      _nodes = create_test_graph(store_name, [
        node_count: @small_graph_size,
        topology: :barabasi_albert
      ])
      
      # Run PageRank with different iteration counts to measure convergence speed
      iterations = [5, 10, 20, 30]
      
      Enum.each(iterations, fn iter ->
        {result, time} = measure(fn ->
          # Use Store.traverse with :page_rank since direct module is not available
          Store.traverse(store_name, :page_rank, [iterations: iter, damping: 0.85])
        end)
        
        # Output top 5 ranked nodes for verification
        top_nodes = case result do
          {:ok, rankings} when is_map(rankings) ->
            rankings
            |> Enum.sort_by(fn {_node, rank} -> -rank end)
            |> Enum.take(5)
          _ -> []
        end
        
        IO.puts("PageRank with #{iter} iterations on #{@small_graph_size} nodes took #{time}ms")
        IO.puts("Top 5 ranked nodes: #{inspect(top_nodes)}")
      end)
    end
    
    @tag timeout: 300_000 # Allow up to 5 minutes for this test 
    test "subscription performance with very large numbers of subscribers", %{store_name: store_name} do
      # Create a large number of subscribers
      subscriber_counts = [100, 500, 1000]
      
      # Measure for different subscriber counts
      Enum.each(subscriber_counts, fn count ->
        # Create subscribers
        subscribers = Enum.map(1..count, fn _i ->
          # Create a minimal subscriber process
          spawn_link(fn ->
            # Simple receive loop
            receive do
              {:event, _event} -> :ok
              after 10_000 -> :timeout
            end
          end)
        end)
        
        # Register all subscribers for all events
        Enum.each(subscribers, fn pid ->
          Store.subscribe(store_name, pid, [Node, Edge])
        end)
        
        # Measure time to publish an event to all subscribers
        {_, publish_time} = measure(fn ->
          # Create an event with correct function signature
          # Using Event.new/4 instead of Event.new/1
          event = Event.new(
            :insert,
            Node,
            Node.new(%{id: "test", type: "test", data: %{}}),
            System.system_time(:millisecond)
          )
          
          # Use the correct function to publish events
          Store.publish(store_name, event)
          
          # Give the system a moment to process all messages
          Process.sleep(10)
        end)
        
        # Calculate average time per subscriber
        avg_time = publish_time / count
        
        IO.puts("Publishing a single event to #{count} subscribers took #{publish_time}ms (#{Float.round(avg_time, 3)}ms per subscriber)")
      end)
    end
    
    @tag timeout: 300_000 # Allow up to 5 minutes for this test
    test "connected components performance", %{store_name: store_name} do
      # Explicitly set the current algorithm store
      Process.put(:current_algorithm_store, store_name)
      
      # Create networks with different connectedness properties
      topologies = [
        {:random, "Random graph"},
        {:watts_strogatz, "Small-world graph"},
        {:barabasi_albert, "Scale-free graph"}
      ]
      
      Enum.each(topologies, fn {topology, description} ->
        # Create a new test store for each topology to avoid interference
        {:ok, test_store} = Store.start_link(name: "performance_test_#{:rand.uniform(10000)}")
        test_store_name = GenServer.call(test_store, :get_name)
        Process.put(:current_algorithm_store, test_store_name)
        
        IO.puts("\nTesting connected components on #{description}")
        _nodes = create_test_graph(test_store_name, [
          node_count: @small_graph_size,  # Use smaller size for component analysis
          topology: topology
        ])
        
        {result, time} = measure(fn ->
          # Use Store.traverse with :connected_components since direct module is not available
          Store.traverse(test_store_name, :connected_components, [])
        end)
        
        # Process result based on the actual return format
        components = case result do
          {:ok, comps} when is_list(comps) -> comps
          _ -> []
        end
        
        IO.puts("Found #{length(components)} connected components in #{time}ms")
        
        # Output component size distribution if we have actual components
        sizes = components 
          |> Enum.map(fn component -> 
             if is_list(component), do: length(component), else: 0
           end)
          |> Enum.sort(:desc)
          |> Enum.take(5)
        
        IO.puts("Top 5 component sizes: #{inspect(sizes)}")
      end)
    end
  end
  
  describe "subscription performance" do
    setup do
      # Create a smaller store for quicker testing
      {:ok, store} = Store.start_link(name: "performance_test_#{:rand.uniform(10000)}")
      
      # Get the store name to avoid PID references
      store_name = GenServer.call(store, :get_name)
      
      %{store_name: store_name}
    end
    
    @tag timeout: 60_000
    test "event publishing performance", %{store_name: store_name} do
      # Test publishing different types of events with proper event structures
      node_events = Enum.map(1..100, fn i -> 
        %GraphOS.Store.Event{
          id: "event_#{i}",
          type: :create,
          topic: :node,
          entity_type: :node,
          entity_id: "n#{i}",
          data: %{name: "Node #{i}"},
          timestamp: System.system_time(:millisecond)
        } 
      end)
      
      edge_events = Enum.map(1..100, fn i -> 
        %GraphOS.Store.Event{
          id: "event_edge_#{i}",
          type: :create,
          topic: :edge,
          entity_type: :edge,
          entity_id: "e#{i}",
          data: %{source: "n1", target: "n#{i}"},
          timestamp: System.system_time(:millisecond)
        } 
      end)
      
      custom_events = Enum.map(1..100, fn i -> 
        %GraphOS.Store.Event{
          id: "event_custom_#{i}",
          type: :custom,
          topic: "custom_topic",
          entity_type: :node,
          entity_id: "c#{i}",
          data: %{custom: true},
          timestamp: System.system_time(:millisecond)
        } 
      end)
      
      # Measure time to publish events with no subscribers
      {_, time_node} = measure(fn ->
        Enum.each(node_events, fn event -> 
          Store.publish(store_name, event)
        end)
      end)
      
      {_, time_edge} = measure(fn ->
        Enum.each(edge_events, fn event -> 
          Store.publish(store_name, event)
        end)
      end)
      
      {_, time_custom} = measure(fn ->
        Enum.each(custom_events, fn event -> 
          Store.publish(store_name, event)
        end)
      end)
      
      IO.puts("Publishing 100 node events took #{time_node}ms")
      IO.puts("Publishing 100 edge events took #{time_edge}ms")
      IO.puts("Publishing 100 custom events took #{time_custom}ms")
      
      # Measure publishing with many events and many subscribers
      {_, mass_publish_time} = measure(fn ->
        # Generate 1000 different events
        events = Enum.map(1..1000, fn i ->
          if rem(i, 3) == 0 do
            Event.create(:node, "node#{i}", %{type: "person", data: %{name: "Person #{i}"}})
          else
            Event.create(:edge, "edge#{i}", %{source: "src#{i}", target: "tgt#{i}"})
          end
        end)
        
        # Publish all events
        Enum.each(events, fn event ->
          Store.publish(store_name, event)
        end)
      end)
      
      IO.puts("Publishing 1000 mixed events took #{mass_publish_time}ms (#{mass_publish_time / 1000}ms per event)")
    end
    
    @tag timeout: 60_000
    test "subscription performance with very large numbers of subscribers", %{store_name: store_name} do
      # Create a large number of subscribers
      subscriber_counts = [10, 100, 1000]
      
      # Measure for different subscriber counts
      Enum.each(subscriber_counts, fn count ->
        # Create subscribers
        subscription_ids = Enum.map(1..count, fn _ ->
          {:ok, sub_id} = Store.subscribe(store_name, Node, events: [:update])
          sub_id
        end)
        
        # Measure update performance
        {_, update_time} = measure(fn ->
          # Publish a single update event 
          event = Event.update(:node, "test_node", %{type: "person", data: %{updated_at: System.system_time(:second)}})
          Store.publish(store_name, event)
        end)
        
        IO.puts("Publishing a single event to #{count} subscribers took #{update_time}ms (#{update_time / count}ms per subscriber)")
        
        # Clean up subscribers
        Enum.each(subscription_ids, fn sub_id ->
          Store.unsubscribe(store_name, sub_id)
        end)
      end)
    end
  end
end
