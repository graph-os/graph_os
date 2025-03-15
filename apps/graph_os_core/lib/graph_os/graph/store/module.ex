defmodule GraphOS.Graph.Store.Module do
  @moduledoc """
  Defines a graph store module with dynamic configuration.
  Similar to how Ecto.Repo works, this allows for compile-time defined
  store modules that internally handle connections.
  """
  
  defmacro __using__(opts) do
    quote do
      @store_adapter unquote(opts[:adapter] || GraphOS.Graph.Store.ETS)
      @store_name __MODULE__
      @store_options unquote(opts[:options] || [])
      
      def start_link(options \\ []) do
        options = Keyword.merge(@store_options, options)
        GraphOS.Graph.Store.Supervisor.start_store(@store_name, @store_adapter, options)
      end
      
      def child_spec(options) do
        %{
          id: @store_name,
          start: {__MODULE__, :start_link, [options]},
          type: :supervisor
        }
      end
      
      def put_node(node), do: GraphOS.Graph.Store.Server.put_node(@store_name, node)
      def get_node(id), do: GraphOS.Graph.Store.Server.get_node(@store_name, id)
      def put_edge(edge), do: GraphOS.Graph.Store.Server.put_edge(@store_name, edge)
      def query(query, options \\ []), do: GraphOS.Graph.Store.Server.query(@store_name, query, options)
      def transaction(fun), do: GraphOS.Graph.Store.Server.transaction(@store_name, fun)
      def clear, do: GraphOS.Graph.Store.Server.clear(@store_name)
      def get_stats, do: GraphOS.Graph.Store.Server.get_stats(@store_name)
      
      # Add cross-store query functions
      def query_across(stores, query, options \\ []) do
        GraphOS.Graph.Store.CrossQuery.execute(@store_name, stores, query, options)
      end
      
      def diff(other_store, options \\ []) do
        GraphOS.Graph.Store.CrossQuery.diff(@store_name, other_store, options)
      end
      
      def dynamic_store(name, options \\ []) do
        GraphOS.Graph.Store.Dynamic.get_or_start(@store_name, name, options)
      end
      
      def for_repo(repo_path, options \\ []) do
        name = "#{@store_name}:#{repo_path}"
        dynamic_store(name, options)
      end
      
      def for_branch(repo_path, branch, options \\ []) do
        name = "#{@store_name}:#{repo_path}:#{branch}"
        
        # Add git metadata to options
        options = Keyword.put(options, :git_metadata, %{
          repo_path: repo_path,
          branch: branch
        })
        
        dynamic_store(name, options)
      end
    end
  end
end
