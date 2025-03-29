defmodule Mix.Tasks.Graphos.Benchmark do
  @moduledoc """
  Mix task for running GraphOS performance benchmarks.
  
  ## Usage
  
  ```bash
  # Run with default parameters
  mix graphos.benchmark
  
  # Run with custom parameters
  mix graphos.benchmark --nodes=5000 --edges=25000 --trials=3
  ```
  
  ## Options
  
  * `--nodes` - Number of nodes in the test graph (default: 10,000)
  * `--edges` - Number of edges in the test graph (default: 50,000)
  * `--trials` - Number of trials for each benchmark (default: 1)
  * `--verbose` - Show detailed output for all trials
  * `--run-tests` - Run performance-specific tests before benchmarking
  """
  
  use Boundary, deps: [GraphOS.Store]
  use Mix.Task
  
  alias GraphOS.Store, as: Store
  alias Logger
  
  @default_node_count 10_000
  @default_edge_count 50_000
  
  @shortdoc "Run GraphOS performance benchmarks"
  
  @impl Mix.Task
  def run(args) do
    # Set logger level to warning to suppress debug output
    Logger.configure(level: :warning)
    
    # Start all required applications
    Application.ensure_all_started(:graph_os_graph)
    
    # Ensure the Registry is started
    {:ok, _} = Registry.start_link(keys: :unique, name: Store.Registry)
    
    # Parse command line options
    {opts, _, _} = OptionParser.parse(args, 
      strict: [
        nodes: :integer,
        edges: :integer,
        trials: :integer,
        verbose: :boolean,
        "run-tests": :boolean
      ]
    )
    
    # Extract parameters with defaults
    node_count = Keyword.get(opts, :nodes, @default_node_count)
    edge_count = Keyword.get(opts, :edges, @default_edge_count)
    trials = Keyword.get(opts, :trials, 1)
    verbose = Keyword.get(opts, :verbose, false)
    run_tests = Keyword.get(opts, :"run-tests", false)
    
    # Run performance tests if requested
    if run_tests do
      IO.puts("\n\e[1;35m=============================================\e[0m")
      IO.puts("\e[1;35mRunning GraphOS Performance Tests\e[0m")
      IO.puts("\e[1;35m=============================================\e[0m\n")
      
      # Run only performance-tagged tests with log level warning to suppress debug logs
      System.cmd("mix", ["test", "--only", "performance", "--log-level", "warning"], into: IO.stream(:stdio, :line))
      
      IO.puts("\n\e[1;35m=============================================\e[0m")
      IO.puts("\e[1;35mPerformance Tests Completed\e[0m")
      IO.puts("\e[1;35m=============================================\e[0m\n")
    end
    
    # Start benchmark
    IO.puts("\e[1;36m=============================================\e[0m")
    IO.puts("\e[1;36mGraphOS Performance Optimization Benchmark\e[0m")
    IO.puts("\e[1;36m=============================================\e[0m\n")

    IO.puts("\e[1;33mConfiguration:\e[0m")
    IO.puts("- Nodes: #{node_count}")
    IO.puts("- Edges: #{edge_count}")
    IO.puts("- Trials: #{trials}\n")

    # Set configuration
    edge_types = ["friend", "colleague", "family", "follows"]
    
    # Set up test stores
    # Standard store (no optimizations)
    standard_store = "standard_benchmark_#{:rand.uniform(10000)}"
    {:ok, _} = Store.start_link(name: standard_store, adapter: Store.Adapter.ETS)
    
    # Optimized store (with all optimizations)
    optimized_store = "optimized_benchmark_#{:rand.uniform(10000)}"
    {:ok, _} = Store.start_link(name: optimized_store, adapter: Store.Adapter.ETS, compressed: true)
    Process.put(:current_algorithm_store, optimized_store)
    
    # Generate identical test data
    IO.puts "\e[1;34mGenerating #{node_count} nodes and #{edge_count} edges...\e[0m"
    
    # Create nodes
    node_module = Application.get_env(:graph_os_store, :node_module, Store.Node)
    edge_module = Application.get_env(:graph_os_store, :edge_module, Store.Edge)
    
    {node_time, node_list} = :timer.tc(fn ->
      nodes = Enum.map(1..node_count, fn i ->
        node = node_module.new(%{
          id: "node_#{i}",
          data: %{
            "name" => "Test Node #{i}",
            "value" => :rand.uniform(1000),
            "created_at" => System.system_time(:second)
          }
        })
        Store.insert(standard_store, node_module, node)
        Store.insert(optimized_store, node_module, node)
        node
      end)
      # Explicitly return the list of nodes
      nodes
    end)
    
    # Create edges with different types to ensure better connectivity
    start_time = System.monotonic_time(:millisecond)
    _edges = Enum.map(1..edge_count, fn i ->
      # More structured approach to ensure connectivity
      # Connect each node to at least one other node for better path finding
      source_idx = rem(i, length(node_list))
      target_idx = rem(i + 1 + :rand.uniform(10), length(node_list))
      # Get the actual node objects using the indices
      source = Enum.at(node_list, source_idx) 
      target = Enum.at(node_list, target_idx)
      # Select edge type based on remainder
      edge_type = Enum.at(edge_types, rem(i, length(edge_types)))
      
      edge = edge_module.new(%{
        id: "edge_#{i}",
        source: source.id,
        target: target.id,
        # Set weight directly on the edge in addition to data
        weight: :rand.uniform(100),
        data: %{
          "type" => edge_type,
          "weight" => :rand.uniform(100),
          "created_at" => System.system_time(:second)
        }
      })
      
      Store.insert(standard_store, edge_module, edge)
      Store.insert(optimized_store, edge_module, edge)
      edge
    end)
    end_time = System.monotonic_time(:millisecond)
    edge_time = end_time - start_time
    
    IO.puts "\e[1;34mCreated #{node_count} nodes in #{format_float(node_time / 1_000_000)}s\e[0m"
    IO.puts "\e[1;34mCreated #{edge_count} edges in #{format_float(edge_time / 1000)}s\e[0m"
    
    # Select test nodes - use a simple approach to pick a node
    test_node = hd(node_list)  # Just pick the first node for simplicity
    
    # Benchmark 1: Edge Type Filtering
    IO.puts "\n\e[1;32m#1: Edge Type Filtering\e[0m"
    IO.puts "\e[90m-------------------\e[0m"
    
    type_filtering_results = Enum.map(1..trials, fn trial ->
      # Traditional filtering (without index)
      {standard_time, standard_results} = :timer.tc(fn ->
        # Get all edges with an empty filter
        {:ok, all_edges} = Store.all(standard_store, edge_module, %{})
        Enum.filter(all_edges, fn edge -> 
          Map.get(edge.data, "type") == "friend"
        end)
      end)
      
      # Optimized filtering (with type index)
      {optimized_time, optimized_results} = :timer.tc(fn ->
        # Use the store API instead of direct adapter reference
        {:ok, typed_edges} = Store.query(optimized_store, 
                                      edge_module, 
                                      %{type: "friend"},
                                      [use_type_index: true])
        typed_edges
      end)
      
      speedup = standard_time / optimized_time
      
      # Add color based on speedup - green for better, red for worse
      speedup_color = if speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
      
      if verbose do
        IO.puts "\e[1;33mTrial #{trial}:\e[0m"
        IO.puts "  \e[1;33mStandard:\e[0m #{format_float(standard_time / 1_000)}ms (#{length(standard_results)} results)"
        IO.puts "  \e[1;33mOptimized:\e[0m #{format_float(optimized_time / 1_000)}ms (#{length(optimized_results)} results)"
        IO.puts "  \e[1;33mSpeedup:\e[0m #{speedup_color}#{format_float(speedup)}x\e[0m"
      end
      
      %{standard: standard_time, optimized: optimized_time, speedup: speedup}
    end)
    
    # Report average results
    avg_standard = Enum.sum(Enum.map(type_filtering_results, & &1.standard)) / trials / 1_000
    avg_optimized = Enum.sum(Enum.map(type_filtering_results, & &1.optimized)) / trials / 1_000
    avg_speedup = Enum.sum(Enum.map(type_filtering_results, & &1.speedup)) / trials
    
    # Add color based on speedup - green for better, red for worse
    avg_speedup_color = if avg_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    
    IO.puts "\e[1;33mAverage standard filtering time:\e[0m #{format_float(avg_standard)}ms"
    IO.puts "\e[1;33mAverage optimized filtering time:\e[0m #{format_float(avg_optimized)}ms"
    IO.puts "\e[1;33mAverage speedup:\e[0m #{avg_speedup_color}#{format_float(avg_speedup)}x\e[0m"
    
    # Benchmark 2: Filtered Traversal
    IO.puts "\n\e[1;32m#2: Edge Type + Source Node Filtering\e[0m"
    IO.puts "\e[90m--------------------------------\e[0m"
    
    traversal_results = Enum.map(1..trials, fn trial ->
      # Traditional traversal
      {standard_time, standard_results} = :timer.tc(fn ->
        # Get all edges with an empty filter
        {:ok, all_edges} = Store.all(standard_store, edge_module, %{})
        Enum.filter(all_edges, fn edge -> 
          Map.get(edge.data, "type") == "friend" && edge.source == test_node.id
        end)
      end)
      
      # Optimized traversal using the type and source indices
      {optimized_time, optimized_results} = :timer.tc(fn ->
        # Use the store API instead of direct adapter reference
        {:ok, source_edges} = Store.query(optimized_store,
                                      edge_module,
                                      %{source: test_node.id, type: "friend"},
                                      [use_indexes: true])
        source_edges
      end)
      
      speedup = standard_time / optimized_time
      
      # Add color based on speedup - green for better, red for worse
      speedup_color = if speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
      
      if verbose do
        IO.puts "\e[1;33mTrial #{trial}:\e[0m"
        IO.puts "  \e[1;33mStandard:\e[0m #{format_float(standard_time / 1_000)}ms (#{length(standard_results)} results)"
        IO.puts "  \e[1;33mOptimized:\e[0m #{format_float(optimized_time / 1_000)}ms (#{length(optimized_results)} results)"
        IO.puts "  \e[1;33mSpeedup:\e[0m #{speedup_color}#{format_float(speedup)}x\e[0m"
      end
      
      %{standard: standard_time, optimized: optimized_time, speedup: speedup}
    end)
    
    # Report average results
    avg_standard = Enum.sum(Enum.map(traversal_results, & &1.standard)) / trials / 1_000
    avg_optimized = Enum.sum(Enum.map(traversal_results, & &1.optimized)) / trials / 1_000
    avg_speedup = Enum.sum(Enum.map(traversal_results, & &1.speedup)) / trials
    
    # Add color based on speedup - green for better, red for worse
    avg_speedup_color = if avg_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    
    IO.puts "\e[1;33mAverage standard traversal time:\e[0m #{format_float(avg_standard)}ms"
    IO.puts "\e[1;33mAverage optimized traversal time:\e[0m #{format_float(avg_optimized)}ms"
    IO.puts "\e[1;33mAverage speedup:\e[0m #{avg_speedup_color}#{format_float(avg_speedup)}x\e[0m"
    
    # Benchmark 3: Path Finding with Cache
    IO.puts "\n\e[1;32m#3: Path Finding Performance\e[0m"
    IO.puts "\e[90m-------------------------\e[0m"
    
    # First path find (uncached)
    # Use nodes that are likely to have a path between them
    source_node = Enum.at(node_list, 0)
    target_node = Enum.at(node_list, div(length(node_list), 2))
    
    path_results = Enum.map(1..trials, fn trial ->
      # Warm up the cache for the first trial
      if trial == 1 do
        # For the first trial, we don't need to clear the cache explicitly
        # as it should be empty on the first run
        :ok
      end
      
      # Regular path finding (no caching)
      {standard_time, _standard_result} = :timer.tc(fn ->
        # Handle the case where no path exists gracefully
        case Store.traverse(standard_store, :shortest_path, [source_node.id, target_node.id]) do
          {:ok, path} -> path
          {:error, _} -> []
        end
      end)
      
      # Cached path finding
      {optimized_time, _optimized_result} = :timer.tc(fn ->
        # Handle the case where no path exists gracefully
        case Store.traverse(optimized_store, :shortest_path, [source_node.id, target_node.id]) do
          {:ok, path} -> path
          {:error, _} -> []
        end
      end)
      
      speedup = standard_time / optimized_time
      
      # Add color based on speedup - green for better, red for worse
      speedup_color = if speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
      
      if verbose do
        IO.puts "\e[1;33mTrial #{trial}:\e[0m"
        IO.puts "  \e[1;33mUncached:\e[0m #{format_float(standard_time / 1_000)}ms"
        IO.puts "  \e[1;33mCached:\e[0m #{format_float(optimized_time / 1_000)}ms"
        IO.puts "  \e[1;33mSpeedup:\e[0m #{speedup_color}#{format_float(speedup)}x\e[0m"
      end
      
      %{uncached: standard_time, cached: optimized_time, speedup: speedup}
    end)
    
    # Report average results
    avg_uncached = Enum.sum(Enum.map(path_results, & &1.uncached)) / trials / 1_000
    avg_cached = Enum.sum(Enum.map(path_results, & &1.cached)) / trials / 1_000
    avg_speedup = Enum.sum(Enum.map(path_results, & &1.speedup)) / trials
    
    # Add color based on speedup - green for better, red for worse
    avg_speedup_color = if avg_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    
    IO.puts "\e[1;33mAverage uncached path time:\e[0m #{format_float(avg_uncached)}ms"
    IO.puts "\e[1;33mAverage cached path time:\e[0m #{format_float(avg_cached)}ms"
    IO.puts "\e[1;33mAverage speedup:\e[0m #{avg_speedup_color}#{format_float(avg_speedup)}x\e[0m"
    
    # Benchmark 4: Memory Usage 
    IO.puts "\n\e[1;32m#4: Memory Efficiency\e[0m"
    IO.puts "\e[90m-------------------\e[0m"
    
    standard_memory = measure_memory_usage(standard_store)
    optimized_memory = measure_memory_usage(optimized_store)
    memory_savings = (1 - optimized_memory / standard_memory) * 100
    
    # Add color based on memory savings - green for better, red for worse
    memory_color = if memory_savings > 0, do: "\e[1;32m", else: "\e[1;31m"
    
    IO.puts "\e[1;33mStandard store memory:\e[0m #{humanize_bytes(standard_memory)} (#{standard_memory} bytes)"
    IO.puts "\e[1;33mOptimized store memory:\e[0m #{humanize_bytes(optimized_memory)} (#{optimized_memory} bytes)"
    IO.puts "\e[1;33mMemory savings:\e[0m #{memory_color}#{format_float(memory_savings)}%\e[0m"
    
    # Benchmark 5: Very Large Graph Optimization
    IO.puts "\n\e[1;32m#5: Very Large Graph Traversal Optimization\e[0m"
    IO.puts "\e[90m------------------------------------\e[0m"
    
    # Create a sample edge for each optimization method to test with
    # Use consistent test data to ensure fair comparison
    test_source = hd(node_list).id
    test_type = "friend"
    
    # Add more edges of this type to make the optimization more visible
    for _ <- 1..50 do
      target = Enum.random(node_list).id
      edge = edge_module.new(%{source: test_source, target: target, data: %{"type" => test_type}})
      {:ok, _} = Store.insert(optimized_store, edge_module, edge)
      {:ok, _} = Store.insert(standard_store, edge_module, edge)
    end
    
    very_large_results = Enum.map(1..trials, fn trial ->
      # Test 1: Standard approach (filter all edges)
      {standard_time, standard_results} = :timer.tc(fn ->
        {:ok, all_edges} = Store.all(optimized_store, edge_module, %{})
        Enum.filter(all_edges, fn edge -> 
          Map.get(edge.data, "type") == test_type && 
          edge.source == test_source
        end)
      end)
      
      # Test 2: Index optimization approach (composite index)
      {optimized_time, optimized_results} = :timer.tc(fn ->
        # Use the store API instead of direct adapter reference
        {:ok, edges} = Store.query(optimized_store,
                                      edge_module,
                                      %{source: test_source, type: test_type},
                                      [use_indexes: true])
        edges
      end)
      
      # Test 3: Parallel optimization approach (for very large graphs)
      {parallel_time, parallel_results} = :timer.tc(fn ->
        # Use the store API instead of direct adapter reference
        {:ok, edges} = Store.query(optimized_store,
                                      edge_module,
                                      %{source: test_source, type: test_type},
                                      [use_indexes: true, max_concurrency: 4])
        edges
      end)
      
      # Calculate speedups
      opt_speedup = standard_time / optimized_time
      par_speedup = standard_time / parallel_time
      
      # Display results for this trial if verbose
      if verbose do
        IO.puts "\e[1;33mTrial #{trial}:\e[0m"
        IO.puts "  \e[1;33mStandard approach:\e[0m #{format_float(standard_time / 1_000)}ms (#{length(standard_results)} results)"
        IO.puts "  \e[1;33mOptimized index:\e[0m #{format_float(optimized_time / 1_000)}ms (#{length(optimized_results)} results)"
        IO.puts "  \e[1;33mParallel processing:\e[0m #{format_float(parallel_time / 1_000)}ms (#{length(parallel_results)} results)"
        color_opt = if opt_speedup > 1.0, do: "\e[1;32m", else: "\e[1;31m"
        color_par = if par_speedup > 1.0, do: "\e[1;32m", else: "\e[1;31m"
        IO.puts "  \e[1;33mIndex optimization speedup:\e[0m #{color_opt}#{format_float(opt_speedup)}x\e[0m"
        IO.puts "  \e[1;33mParallel optimization speedup:\e[0m #{color_par}#{format_float(par_speedup)}x\e[0m"
      end
      
      %{standard: standard_time, optimized: optimized_time, parallel: parallel_time, 
        opt_speedup: opt_speedup, par_speedup: par_speedup}
    end)
    
    # Calculate averages
    avg_standard = Enum.sum(Enum.map(very_large_results, & &1.standard)) / trials / 1_000
    avg_optimized = Enum.sum(Enum.map(very_large_results, & &1.optimized)) / trials / 1_000
    avg_parallel = Enum.sum(Enum.map(very_large_results, & &1.parallel)) / trials / 1_000
    avg_opt_speedup = Enum.sum(Enum.map(very_large_results, & &1.opt_speedup)) / trials
    avg_par_speedup = Enum.sum(Enum.map(very_large_results, & &1.par_speedup)) / trials
    
    # Add colors based on speedups
    opt_color = if avg_opt_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    par_color = if avg_par_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    
    # Display average results
    IO.puts "\e[1;33mAverage standard filtering time:\e[0m #{format_float(avg_standard)}ms"
    IO.puts "\e[1;33mAverage optimized index time:\e[0m #{format_float(avg_optimized)}ms"
    IO.puts "\e[1;33mAverage parallel processing time:\e[0m #{format_float(avg_parallel)}ms"
    IO.puts "\e[1;33mAverage index optimization speedup:\e[0m #{opt_color}#{format_float(avg_opt_speedup)}x\e[0m"
    IO.puts "\e[1;33mAverage parallel optimization speedup:\e[0m #{par_color}#{format_float(avg_par_speedup)}x\e[0m"
    
    # Clean up
    Store.stop(standard_store)
    Store.stop(optimized_store)
    
    # Output summary
    IO.puts "\n\e[1;36m=============================================\e[0m"
    IO.puts "\e[1;36mBenchmark Summary\e[0m"
    IO.puts "\e[1;36m=============================================\e[0m"
    
    # Add color coding for summary results
    edge_filtering_speedup = Enum.sum(Enum.map(type_filtering_results, & &1.speedup)) / trials
    edge_filtering_color = if edge_filtering_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    traversal_filtering_speedup = Enum.sum(Enum.map(traversal_results, & &1.speedup)) / trials
    traversal_filtering_color = if traversal_filtering_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    path_caching_speedup = Enum.sum(Enum.map(path_results, & &1.speedup)) / trials
    path_caching_color = if path_caching_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    memory_efficiency_color = if memory_savings > 0, do: "\e[1;32m", else: "\e[1;31m"
    very_large_opt_color = if avg_opt_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    very_large_par_color = if avg_par_speedup >= 1.0, do: "\e[1;32m", else: "\e[1;31m"
    
    IO.puts "\e[1;33mEdge Type Filtering:\e[0m #{edge_filtering_color}#{format_float(edge_filtering_speedup)}x faster\e[0m"
    IO.puts "\e[1;33mTraversal Filtering:\e[0m #{traversal_filtering_color}#{format_float(traversal_filtering_speedup)}x faster\e[0m"
    IO.puts "\e[1;33mPath Caching:\e[0m #{path_caching_color}#{format_float(path_caching_speedup)}x faster\e[0m"
    IO.puts "\e[1;33mMemory Efficiency:\e[0m #{memory_efficiency_color}#{format_float(memory_savings)}% reduction\e[0m"
    IO.puts "\e[1;33mVery Large Graph - Index Optimization:\e[0m #{very_large_opt_color}#{format_float(avg_opt_speedup)}x faster\e[0m"
    IO.puts "\e[1;33mVery Large Graph - Parallel Processing:\e[0m #{very_large_par_color}#{format_float(avg_par_speedup)}x faster\e[0m"
    
    IO.puts "\n\e[1;32mBenchmark complete.\e[0m"
  end
  
  # Helper function to format floats to 2 decimal places
  defp format_float(float) do
    :erlang.float_to_binary(float, [decimals: 2])
  end
  
  # Helper function to humanize bytes
  defp humanize_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{format_float(bytes / 1_000_000_000)} GB"
      bytes >= 1_000_000 -> "#{format_float(bytes / 1_000_000)} MB"
      bytes >= 1_000 -> "#{format_float(bytes / 1_000)} KB"
      true -> "#{bytes} bytes"
    end
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
