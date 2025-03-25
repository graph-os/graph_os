## Refactoring Plan

# 1. GraphOS.Store
`GraphOS.Store` (previously `GraphOS.Graph`) is now the main entrypoint for storing data or state for GraphOS.Core modules.

`Store` should have a minimal interface, and enforce private modules/methods for internal operations.

`Store` should have a similar interface to `Ecto.Repo` (although it should not impose on `Ecto.Repo` module name, eg. `GraphOS.Repo`).

`Store` should enforce data integrity with a `GraphOS.Schema` module. (`GraphOS.Store.Schema` already exists, and should be moved to `GraphOS.Schema`).

`Store` should use `GraphOS.Store.StoreAdapter` as driver for different storage engines. We will only support `ETS` for now, but allow for other adapters to be added in the future.

Since we might support multiple store adapters, we should implement a registry for stores, in case we have multiple stores in the same application. Eg. ETS and Ecto.

## 1.1 Behaviour
The exposed API from `GraphOS.Store` should be minimal and only include:

### 1.1.1 Main API
- `start/0` - Should start the base store system with default configuration.
- `start/1` - Should start the store with given options and register it in the registry.
- `stop/0` - Should stop the entire store system and unregister from the registry.
- `execute/1` - Should execute a GraphOS.Store.{Operation, Query, Transaction}

### 1.1.2 Graph Lifecycle API
- `start_graph/1` - Starts a specific graph module and registers it in the registry.
- `start_graph/2` - Starts a specific graph module with options and registers it in the registry.
- `stop_graph/1` - Stops a specific graph module and unregisters it from the registry.
- `list_graphs/0` - Lists all currently active graphs in the registry.
- `graph_info/1` - Returns information about a specific graph, including stats and schema.

### 1.1.3 Operations
> Note: Shorthand functions that mimic basic CRUD operations.
- `insert/2` - Should insert a new GraphOS.Store.{Graph, Node, Edge}
- `update/2` - Should update an existing GraphOS.Store.{Graph, Node, Edge}
- `delete/1` - Should delete a GraphOS.Store.{Graph, Node, Edge}
- `get/2` - Should get a GraphOS.Store.{Graph, Node, Edge} by id
- `traverse/3` - Traverses a graph starting from a node using specified algorithm
- `match/2` - Finds nodes or edges matching specified patterns

### 1.1.4 Cross-Graph Operations
- `cross_traverse/3` - Traverses across multiple graphs starting from a node
- `cross_match/2` - Finds nodes or edges matching patterns across multiple graphs

# 2. Store entities (tables)

## 2.1 Storage Implementation
GraphOS.Store uses a simplified ETS-based storage implementation with a unified table structure:

```elixir
# Tables structure
table :graphs do
  field :id, :integer, required: true     # Auto-incrementing numeric ID
  field :module, :atom, required: true    # Graph module (e.g., GraphOS.Core.Access.Policy)
  field :temp, :boolean, default: false   # Whether this graph is temporary
  field :meta, :map, default: %{}         # Additional metadata
end

table :nodes do
  field :graph_id, :integer, required: true  # Reference to graphs.id
  field :id, :string, required: true         # Unique ID within the system
  field :type, :atom, required: true         # Module that defines this node type
  field :data, :map, required: true          # Node data/attributes
end

table :edges do
  field :graph_id, :integer, required: true  # Graph this edge belongs to
  field :id, :string, required: true         # Unique ID within the system
  field :type, :atom, required: true         # Module that defines this edge type
  field :source, :string, required: true     # Source node ID
  field :target, :string, required: true     # Target node ID
  field :data, :map, required: true          # Edge attributes
end
```

This design provides:
1. A single table for all nodes, enabling efficient cross-graph queries
2. A simple integer ID (`graph_id`) for each graph to minimize duplication
3. Special handling for core graphs (e.g., Access.Policy uses `graph_id: 0`)
4. Direct references between nodes in different graphs

## 2.2 Graph
A `GraphOS.Store.Graph` is a named scope for nodes and edges. The intention is to allow for logical grouping, while still allowing for cross-graph queries and operations.

```elixir
defmodule GraphOS.Core.Access.Policy do
  use Boundary, deps: [GraphOS.Core.Files]
  use GraphOS.Store.Graph, 
    temp: false  # This is a permanent graph (default)
  
  # Lifecycle hooks
  @impl GraphOS.Store.Graph
  def on_start(options) do
    # Initialize graph on start
    create_default_permissions()
    {:ok, %{started_at: DateTime.utc_now()}}
  end
  
  @impl GraphOS.Store.Graph
  def on_stop(state) do
    # Cleanup when graph stops
    {:ok, state}
  end
end
```

## 2.3 Node
A Node is a record with a unique identifier in the system, belonging to a specific graph.

```elixir
defmodule GraphOS.Core.Access.Actor do
  use GraphOS.Store.Node,
    graph: GraphOS.Core.Access.Policy

  # Schema definition
  schema do
    field :id, :string, required: true
    field :name, :string, required: true
    field :metadata, :map
  end

  # Basic operations defined automatically
  # create/1, update/2, get/1, delete/1
  
  # Custom operations
  def find_by_name(name_pattern) do
    GraphOS.Store.match(__MODULE__, %{name: name_pattern})
  end
end
```

## 2.4 Edge
An Edge is a relationship between two nodes, using the keys: `source` and `target`. Edges can specify restrictions on which node types can be connected.

```elixir
defmodule GraphOS.Core.Access.Permission do
  use GraphOS.Store.Edge,
    graph: GraphOS.Core.Access.Policy,
    source: [GraphOS.Core.Access.Actor, GraphOS.Core.Access.Group],  # Only these node types can be sources
    target: GraphOS.Core.Access.Scope                                # Only this node type can be target
  
  # Schema definition  
  schema do
    field :source, :string, required: true  # ID of the source node
    field :target, :string, required: true  # ID of the target node
    field :read, :boolean, default: false
    field :write, :boolean, default: false
    field :execute, :boolean, default: false
    field :destroy, :boolean, default: false
  end
end
```

The edge restrictions (`source:` and `target:`) act as constraints during edge creation and query operations. They ensure that:
1. Only specified node types can be connected
2. Queries automatically filter for the correct node types
3. Validation happens at edge creation time

You can also use `source_not:` and `target_not:` to exclude specific node types:

```elixir
use GraphOS.Store.Edge,
  graph: GraphOS.Core.Access.Policy,
  source: GraphOS.Core.Access.Scope,
  target_not: GraphOS.Core.Access.Actor  # Cannot connect to Actor nodes
```

## 2.5 Schema Integration
All graph entities support schema validation through the existing `GraphOS.Store.Schema` system:

```elixir
defmodule GraphOS.Core.Access.Actor do
  use GraphOS.Store.Node,
    graph: GraphOS.Core.Access.Policy

  # Schema definition using a clean DSL
  schema do
    field :id, :string, required: true
    field :name, :string, required: true
    field :metadata, :map
    
    # Optional validation
    validate :name, fn name -> 
      if String.length(name) > 2, do: :ok, else: {:error, "Name too short"}
    end
  end
end
```

## 2.6 Graph-Specific Operations
GraphOS.Store emphasizes graph-specific operations and algorithms:

```elixir
# Traverse the graph from a starting node using BFS
{:ok, connected_nodes} = GraphOS.Store.traverse(:bfs, starting_node_id, max_depth: 3)

# Find the shortest path between two nodes
{:ok, path, distance} = GraphOS.Store.shortest_path(source_id, target_id)

# Find all nodes matching a pattern
{:ok, matching_nodes} = GraphOS.Store.match(Actor, %{name: "John*"})
```

## 2.7 Cross-Graph References
Since all nodes are stored in a single table with graph_id references, cross-graph operations are straightforward:

```elixir
# Create a file in the Files graph
{:ok, file} = GraphOS.Core.Files.File.create(%{
  path: "/projects/app.py",
  name: "app.py",
  extension: ".py"
})

# Create a permission that references the file directly
{:ok, permission} = GraphOS.Core.Access.Permission.create(%{
  source: actor_id,   # Node in Access graph
  target: file.id,    # Node in Files graph
  read: true
})

# Check if an actor can access a file from another graph
can_read = GraphOS.Core.Access.can?(actor_id, file.id, :read)
```

## 2.8 Pattern-Based Scopes
For dynamic resources like files, pattern-based scopes provide a flexible solution:

```elixir
# Create a scope for all Python files
{:ok, python_scope} = GraphOS.Core.Access.Scope.create("python_files", %{
  pattern: %{extension: ".py"},
  target_graph_id: files_graph_id
})

# When checking permissions, match against patterns
def check_file_access(actor_id, file_id, action) do
  # First check direct permissions
  direct_access = GraphOS.Store.match(Permission, %{
    source: actor_id, 
    target: file_id,
    action => true
  }) |> Enum.any?()
  
  if direct_access do
    true
  else
    # Check pattern-based scopes
    file = GraphOS.Store.get(File, file_id)
    
    actor_scopes = get_actor_scopes(actor_id, action)
    Enum.any?(actor_scopes, fn scope ->
      matches_pattern?(file, scope.pattern)
    end)
  end
end
```

## 2.9 Example Usage

```elixir
# Initialize the store
GraphOS.Store.start()

# Start necessary graphs
{:ok, _} = GraphOS.Store.start_graph(GraphOS.Core.Access.Policy)
{:ok, files_graph} = GraphOS.Store.start_graph(GraphOS.Core.Files.Graph)

# Create entities
{:ok, actor} = GraphOS.Core.Access.Actor.create(%{name: "Admin User"})
{:ok, file} = GraphOS.Core.Files.File.create(%{path: "/data/report.pdf"})

# Create cross-graph permission
{:ok, _} = GraphOS.Core.Access.Permission.create(%{
  source: actor.id,
  target: file.id,
  read: true,
  write: true
})

# Query across graphs
{:ok, accessible_files} = GraphOS.Store.match(File, %{
  joins: [
    {Permission, :target, :id, %{source: actor.id, read: true}}
  ]
})

# Traverse across graphs
{:ok, path} = GraphOS.Store.shortest_path(
  actor.id, file.id,
  edge_type: Permission,
  edge_filter: &(&1.read == true)
)
```

## 3. Full Access Control Example

This section demonstrates how the full Access Control system would be implemented with this design:

```elixir
defmodule GraphOS.Core.Access.Policy do
  use Boundary, deps: [GraphOS.Core.Files]
  use GraphOS.Store.Graph, temp: false
  
  # Lifecycle hooks
  @impl GraphOS.Store.Graph
  def on_start(_options) do
    # Initialize graph on start with default resources
    create_default_permissions()
    {:ok, %{started_at: DateTime.utc_now()}}
  end
  
  @impl GraphOS.Store.Graph
  def on_stop(_state) do
    # Cleanup when graph stops
    {:ok, %{}}
  end
  
  # Create default permissions needed for system operation
  defp create_default_permissions do
    # ... implementation
  end
end

defmodule GraphOS.Core.Access.Actor do
  @moduledoc """
  Represents a user or service that can perform actions in the system.
  """
  use GraphOS.Store.Node,
    graph: GraphOS.Core.Access.Policy

  schema do
    field :id, :string, required: true
    field :name, :string, required: true
    field :metadata, :map
  end

  def find_by_name(name_pattern) do
    GraphOS.Store.match(__MODULE__, %{name: name_pattern})
  end
  
  def permissions_graph(actor_id) do
    GraphOS.Store.traverse(:bfs, actor_id, 
      edge_type: GraphOS.Core.Access.Permission,
      direction: :outgoing
    )
  end
  
  def connected_actors(actor_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 3)
    GraphOS.Store.traverse(:bfs, actor_id, 
      max_depth: max_depth, 
      node_type: __MODULE__
    )
  end
  
  def set_name(actor, name) do
    update(actor, %{name: name})
  end
end

defmodule GraphOS.Core.Access.Scope do
  @moduledoc """
  Groups a set of resources as a scope for access control.
  """
  use GraphOS.Store.Node,
    graph: GraphOS.Core.Access.Policy

  schema do
    field :id, :string, required: true
    field :key, :string, required: true
    field :pattern, :map
    field :target_graph_id, :integer
  end

  def create(key, opts \\ %{}) when is_binary(key) do
    # We support creating scopes with explicit node lists or with patterns
    attrs = Map.merge(%{key: key}, opts)
    
    GraphOS.Store.transaction(fn -> 
      with {:ok, scope} <- super(attrs),
           {:ok, _} <- add_nodes(scope, Map.get(opts, :node_ids, [])) do
        {:ok, scope}
      else
        error -> error
      end
    end)
  end

  def add_nodes(scope, node_ids) do
    results = Enum.map(node_ids, &include_node(scope, &1))
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      {:ok, results}
    else
      {:error, "Failed to include some nodes"}
    end
  end

  def include_node(scope, node) do
    GraphOS.Core.Access.Restriction.create(%{
      type: :include, 
      source: scope.id, 
      target: node
    })
  end

  def exclude_node(scope, node) do
    GraphOS.Core.Access.Restriction.create(%{
      type: :exclude, 
      source: scope.id, 
      target: node
    })
  end
  
  # Graph traversal operations
  def included_nodes(scope_id) do
    GraphOS.Store.traverse(:bfs, scope_id, 
      edge_type: GraphOS.Core.Access.Restriction,
      edge_filter: &(&1.data.type == :include),
      direction: :outgoing
    )
  end
  
  def excluded_nodes(scope_id) do
    GraphOS.Store.traverse(:bfs, scope_id, 
      edge_type: GraphOS.Core.Access.Restriction,
      edge_filter: &(&1.data.type == :exclude),
      direction: :outgoing
    )
  end
  
  def find_subgraph(scope_id) do
    GraphOS.Store.Algorithm.connected_components(
      start_node_id: scope_id,
      direction: :outgoing
    )
  end
end

defmodule GraphOS.Core.Access.Restriction do
  @moduledoc """
  A special edge that includes or excludes a node in a scope.
  """
  use GraphOS.Store.Edge,
    graph: GraphOS.Core.Access.Policy,
    source: GraphOS.Core.Access.Scope,       # Only scopes can be sources
    target_not: GraphOS.Core.Access.Actor    # Actor nodes cannot be targets

  schema do
    field :source, :string, required: true
    field :target, :string, required: true
    field :type, {:enum, [:include, :exclude]}, required: true
    
    # Custom validations can be defined inline
    validate fn data ->
      if data.type in [:include, :exclude], do: :ok, else: {:error, "Invalid type"}
    end
  end
  
  def find_by_scope(scope_id) do
    GraphOS.Store.match(__MODULE__, %{source: scope_id})
  end
  
  def find_cycles do
    # Find cyclic dependencies in restrictions
    GraphOS.Store.Algorithm.detect_cycles(edge_type: __MODULE__)
  end
end

defmodule GraphOS.Core.Access.Group do
  @moduledoc """
  A group of actors.
  """
  use GraphOS.Store.Node,
    graph: GraphOS.Core.Access.Policy

  schema do
    field :id, :string, required: true
    field :name, :string, required: true
    field :description, :string
    field :metadata, :map
    field :settings, :map
    field :created_at, :string

    # Validations
    validate :settings, fn settings -> 
      if is_map(settings) && Map.has_key?(settings, :max_members), do: :ok, 
        else: {:error, "Settings must include max_members"}
    end
    
    validate :created_at, &validate_datetime/1
  end
  
  def add_member(group, actor) do
    GraphOS.Core.Access.Membership.create(%{
      source: actor.id,
      target: group.id
    })
  end
  
  def members(group_id) do
    # Find all actors that are members of this group
    {:ok, memberships} = GraphOS.Store.match(GraphOS.Core.Access.Membership, %{
      target: group_id
    })
    
    Enum.map(memberships, fn membership -> 
      {:ok, actor} = GraphOS.Store.get(GraphOS.Core.Access.Actor, membership.source)
      actor
    end)
  end
  
  def member_count(group_id) do
    # Count members without fetching all data
    {:ok, count} = GraphOS.Store.count(GraphOS.Core.Access.Membership, %{
      target: group_id
    })
    count
  end
  
  defp validate_datetime(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, _, _} -> :ok
      _ -> {:error, "Invalid ISO8601 datetime"}
    end
  end
end

defmodule GraphOS.Core.Access.Membership do
  @moduledoc """
  Defines a membership between an actor and a group.
  """
  use GraphOS.Store.Edge,
    graph: GraphOS.Core.Access.Policy,
    source: GraphOS.Core.Access.Actor,    # Only actors can be source
    target: GraphOS.Core.Access.Group     # Only groups can be target
  
  schema do
    field :source, :string, required: true    # Actor ID
    field :target, :string, required: true    # Group ID
    field :role, :string, default: "member"   # Optional role in the group
  end
    
  def find_groups_for_actor(actor_id) do
    # Find all groups an actor belongs to
    {:ok, memberships} = GraphOS.Store.match(__MODULE__, %{source: actor_id})
    
    Enum.map(memberships, fn membership -> 
      {:ok, group} = GraphOS.Store.get(GraphOS.Core.Access.Group, membership.target)
      group
    end)
  end
  
  def find_actors_in_group(group_id) do
    # Find all actors in a group
    {:ok, memberships} = GraphOS.Store.match(__MODULE__, %{target: group_id})
    
    Enum.map(memberships, fn membership -> 
      {:ok, actor} = GraphOS.Store.get(GraphOS.Core.Access.Actor, membership.source)
      actor
    end)
  end
  
  def find_common_groups(actor_ids) when is_list(actor_ids) do
    # Find groups that all specified actors belong to
    groups_per_actor = Enum.map(actor_ids, &find_groups_for_actor/1)
    
    case groups_per_actor do
      [] -> []
      [first | rest] ->
        Enum.reduce(rest, first, fn groups, acc -> 
          MapSet.intersection(MapSet.new(groups), MapSet.new(acc))
        end)
        |> MapSet.to_list()
    end
  end
end

defmodule GraphOS.Core.Access.Permission do
  @moduledoc """
  A permission between a subject (actor or group) and a scope.
  """
  use GraphOS.Store.Edge,
    graph: GraphOS.Core.Access.Policy,
    source: [GraphOS.Core.Access.Group, GraphOS.Core.Access.Actor],  # Either groups or actors
    target: GraphOS.Core.Access.Scope                                # Only scopes
  
  schema do
    field :source, :string, required: true      # Actor or Group ID
    field :target, :string, required: true      # Scope ID
    field :read, :boolean, default: false
    field :write, :boolean, default: false
    field :execute, :boolean, default: false
    field :destroy, :boolean, default: false
  end
    
  def find_by_scope(scope_id) do
    GraphOS.Store.match(__MODULE__, %{target: scope_id})
  end
  
  def find_by_subject(subject_id) do
    GraphOS.Store.match(__MODULE__, %{source: subject_id})
  end
  
  def analyze_permission_flow do
    # Analyze how permissions flow through the graph
    GraphOS.Store.Algorithm.pagerank(
      edge_type: __MODULE__,
      weight_property: "permission_strength"
    )
  end
  
  def permission_paths(actor_id, scope_id) do
    # Find all paths that grant permission between actor and scope
    GraphOS.Store.Algorithm.all_paths(
      source_id: actor_id,
      target_id: scope_id,
      max_depth: 5,
      edge_types: [__MODULE__, GraphOS.Core.Access.Membership]
    )
  end
end

defmodule GraphOS.Core.Access do
  @moduledoc """
  Main module for access control.
  """
  alias GraphOS.Core.Access.{Actor, Group, Membership, Permission, Scope, Restriction}
  
  def init(opts \\ []) do
    GraphOS.Store.start_graph(GraphOS.Core.Access.Policy, opts)
  end

  def stop do
    GraphOS.Store.stop_graph(GraphOS.Core.Access.Policy)
  end

  def can?(actor_id, resource_id, action) when action in [:read, :write, :execute, :destroy] do
    # Use graph traversal to check direct permission
    case GraphOS.Store.shortest_path(
      actor_id, 
      resource_id,
      edge_type: Permission,
      edge_filter: &(Map.get(&1.data, action, false))
    ) do
      {:ok, _path, _distance} -> 
        true
      {:error, _} -> 
        # Check permissions through groups
        group_permission_path?(actor_id, resource_id, action)
    end
  end
  
  defp group_permission_path?(actor_id, resource_id, action) do
    # First check if resource matches any pattern-based scopes
    {:ok, resource} = GraphOS.Store.get(resource_id)
    
    # Get all groups the actor is a member of
    actor_groups = Membership.find_groups_for_actor(actor_id)
    
    # Get all permissions for these groups
    group_permissions = Enum.flat_map(actor_groups, fn group ->
      {:ok, permissions} = Permission.find_by_subject(group.id)
      permissions
    end)
    
    # Check if any permission grants access to this resource
    Enum.any?(group_permissions, fn permission ->
      # Get the scope for this permission
      {:ok, scope} = GraphOS.Store.get(Scope, permission.target)
      
      # Check if the permission has the requested action
      has_permission = Map.get(permission.data, action, false)
      
      # Check if scope matches the resource through pattern or direct inclusion
      resource_in_scope = cond do
        # Direct inclusion through a restriction edge
        Restriction.find_by_scope(scope.id)
        |> Enum.any?(&(&1.data.type == :include && &1.target == resource_id)) ->
          true
          
        # Pattern matching if scope has a pattern
        scope.pattern && matches_pattern?(resource, scope.pattern) ->
          true
          
        # Otherwise not in scope
        true ->
          false
      end
      
      has_permission && resource_in_scope
    end)
  end
  
  defp matches_pattern?(resource, pattern) do
    # Implementation depends on your pattern matching needs
    # This is a simple implementation that checks exact matches on fields
    Enum.all?(pattern, fn {key, value} ->
      Map.get(resource, key) == value
    end)
  end

  def grant(subject_id, scope_id, action) when action in [:read, :write, :execute, :destroy] do
    set_permission(subject_id, scope_id, action, true)
  end

  def revoke(subject_id, scope_id, action) when action in [:read, :write, :execute, :destroy] do
    set_permission(subject_id, scope_id, action, false)
  end
  
  defp set_permission(subject_id, scope_id, action, value) do
    # Find existing permission or create new one
    case Permission.find_by_subject(subject_id) 
         |> Enum.find(fn p -> p.target == scope_id end) do
      nil ->
        # Create new permission
        Permission.create(%{
          source: subject_id,
          target: scope_id,
          action => value
        })
        
      permission ->
        # Update existing permission
        permission_data = Map.put(permission.data, action, value)
        Permission.update(permission.id, %{data: permission_data})
    end
  end
  
  def analyze_access_structure do
    # Perform graph analysis on the entire access control structure
    {:ok, components} = GraphOS.Store.Algorithm.connected_components(
      graph_id: GraphOS.Store.graph_id(GraphOS.Core.Access.Policy)
    )
    
    {:ok, pagerank} = GraphOS.Store.Algorithm.pagerank(
      graph_id: GraphOS.Store.graph_id(GraphOS.Core.Access.Policy)
    )
    
    %{
      components: components,
      central_nodes: Enum.take(Enum.sort_by(pagerank, fn {_, rank} -> -rank end), 5),
      permission_distribution: analyze_permission_distribution()
    }
  end
  
  defp analyze_permission_distribution do
    # Analyze how permissions are distributed in the graph
    {:ok, permissions} = GraphOS.Store.match(Permission, %{})
    
    # Count permissions by type
    permissions
    |> Enum.reduce(%{read: 0, write: 0, execute: 0, destroy: 0}, fn permission, acc ->
      acc
      |> Map.update!(:read, &(&1 + (if permission.data.read, do: 1, else: 0)))
      |> Map.update!(:write, &(&1 + (if permission.data.write, do: 1, else: 0)))
      |> Map.update!(:execute, &(&1 + (if permission.data.execute, do: 1, else: 0)))
      |> Map.update!(:destroy, &(&1 + (if permission.data.destroy, do: 1, else: 0)))
    end)
  end
end

This comprehensive example shows how the entire Access Control system works together, with proper edge restrictions, schema validation, and cross-graph references.

## 4. Refactoring Implementation Plan

Based on the current codebase analysis and the proposed design, here's a detailed plan for implementing this refactoring:

### 4.1 Directory Structure

Current structure:
```
apps/
  graph_os_graph/
    lib/
      graph.ex                   # Will be replaced by store.ex
      store/
        schema.ex               # Will be refactored
        schema_behaviour.ex     # Will be refactored
        algorithm.ex            # Will be preserved and updated
        algorithm/
          ets.ex                # Will be preserved and updated
```

Target structure:
```
apps/
  graph_os_graph/               # No rename needed
    lib/
      store.ex                  # Main entrypoint (replacing graph.ex)
      store/
        graph.ex                # Graph behavior
        node.ex                 # Node behavior
        edge.ex                 # Edge behavior
        schema.ex               # Refactored from current implementation
        schema_behaviour.ex     # Refactored from current implementation
        algorithm.ex            # Keep existing with updates for new API
        algorithm/
          ets.ex                # Keep existing with updates for new API
        adapter/
          ets.ex                # New file for ETS adapter implementation
```

### 4.2 File Changes

#### 4.2.1 Files to Delete

| File | Reason |
|------|--------|
| `apps/graph_os_graph/lib/graph.ex` | Replaced by the new Store API |
| `apps/graph_os_graph/lib/graph/node.ex` | Functionality moved to store/node.ex |
| `apps/graph_os_graph/lib/graph/edge.ex` | Functionality moved to store/edge.ex |

#### 4.2.2 Files to Create

| File | Description |
|------|-------------|
| `apps/graph_os_graph/lib/store.ex` | New main entrypoint for Store API |
| `apps/graph_os_graph/lib/store/graph.ex` | New Graph behavior definition |
| `apps/graph_os_graph/lib/store/node.ex` | New Node behavior definition |
| `apps/graph_os_graph/lib/store/edge.ex` | New Edge behavior definition |
| `apps/graph_os_graph/lib/store/adapter/ets.ex` | New ETS adapter implementation |

#### 4.2.3 Files to Modify

| File | Changes |
|------|---------|
| `apps/graph_os_graph/lib/store/schema.ex` | Update to support new schema DSL and integration with new API |
| `apps/graph_os_graph/lib/store/schema_behaviour.ex` | Update to align with new schema integration |
| `apps/graph_os_graph/lib/store/algorithm.ex` | Update API calls to use new Store interface |
| `apps/graph_os_graph/lib/store/algorithm/ets.ex` | Update to work with new ETS adapter |
| `apps/graph_os_graph/mix.exs` | Update application configuration and dependencies |

#### 4.2.4 Access Control Module Implementation

| File | Description |
|------|-------------|
| `apps/graph_os_core/lib/access/policy.ex` | New file for Access Policy graph |
| `apps/graph_os_core/lib/access/actor.ex` | New file for Actor node |
| `apps/graph_os_core/lib/access/scope.ex` | New file for Scope node |
| `apps/graph_os_core/lib/access/group.ex` | New file for Group node |
| `apps/graph_os_core/lib/access/restriction.ex` | New file for Restriction edge |
| `apps/graph_os_core/lib/access/membership.ex` | New file for Membership edge |
| `apps/graph_os_core/lib/access/permission.ex` | New file for Permission edge |
| `apps/graph_os_core/lib/access.ex` | New file for main Access module |

#### 4.2.5 Other Core Modules (Examples)

| File | Description |
|------|-------------|
| `apps/graph_os_core/lib/files/graph.ex` | New file for Files graph |
| `apps/graph_os_core/lib/files/file.ex` | New file for File node |

### 4.3 Implementation Details

#### 4.3.1 Store Implementation

1. **GraphOS.Store** (`apps/graph_os_graph/lib/store.ex`)
   - Implement the main API (`start/0`, `start/1`, `stop/0`, etc.)
   - Implement graph registry
   - Implement CRUD operations
   - Implement traversal and query operations
   - Implement transaction support

2. **GraphOS.Store.Graph** (`apps/graph_os_graph/lib/store/graph.ex`)
   - Define the Graph behavior
   - Implement `__using__` macro for easy Graph definition
   - Define lifecycle callbacks
   - Implement graph-specific operations

3. **GraphOS.Store.Node** (`apps/graph_os_graph/lib/store/node.ex`)
   - Define the Node behavior
   - Implement `__using__` macro for easy Node definition
   - Implement schema integration
   - Implement node-specific operations

4. **GraphOS.Store.Edge** (`apps/graph_os_graph/lib/store/edge.ex`)
   - Define the Edge behavior
   - Implement `__using__` macro for easy Edge definition
   - Implement source/target validation
   - Implement edge-specific operations

5. **GraphOS.Store.Schema** (`apps/graph_os_graph/lib/store/schema.ex`)
   - Refactor existing schema implementation
   - Update schema DSL for improved syntax
   - Ensure backward compatibility where possible
   - Preserve existing protobuf support

6. **GraphOS.Store.Adapter.ETS** (`apps/graph_os_graph/lib/store/adapter/ets.ex`)
   - Implement ETS-specific storage operations
   - Setup ETS tables with proper configuration
   - Implement efficient querying for cross-graph operations

7. **GraphOS.Store.Algorithm** (`apps/graph_os_graph/lib/store/algorithm.ex`)
   - Update to work with the new Store API
   - Ensure all existing algorithms are maintained:
     - BFS traversal
     - Shortest path
     - Connected components
     - PageRank
     - Minimum spanning tree
   - Add new algorithms for cross-graph operations

8. **GraphOS.Store.Algorithm.ETS** (`apps/graph_os_graph/lib/store/algorithm/ets.ex`)
   - Update to work with the new ETS adapter
   - Optimize algorithms for the new table structure
   - Ensure efficient implementation for cross-graph operations

#### 4.3.2 Boundary Integration

**IMPORTANT:** All modules must define Boundary dependencies. Example:

```elixir
defmodule GraphOS.Store do
  use Boundary, deps: [], exports: [Graph, Node, Edge, Schema, Algorithm]
end

defmodule GraphOS.Core.Access.Policy do
  # No deps to other graphs since this is a root dependency
  use Boundary, deps: [], exports: [Actor, Group, Scope, Permission, Membership, Restriction]
  use GraphOS.Store.Graph, temp: false
end

defmodule GraphOS.Core.Files.Graph do
  use Boundary, deps: [GraphOS.Core.Access.Policy], exports: [File]
  use GraphOS.Store.Graph, temp: false
end
```

The GraphOS.Core.Access.Policy module should have zero dependencies to other graphs since it's a root dependency that others rely on. It should be higher in the dependency hierarchy than all other graphs.

#### 4.3.3 Testing Strategy

1. **Unit Tests**
   - Test each component in isolation
   - Mock dependencies where needed

2. **Integration Tests**
   - Test complete workflows
   - Test cross-graph operations

3. **Test Files to Create or Update**

| Test File | Changes |
|-----------|---------|
| `apps/graph_os_graph/test/store_test.exs` | New tests for Store API |
| `apps/graph_os_graph/test/store/graph_test.exs` | Tests for Graph behavior |
| `apps/graph_os_graph/test/store/node_test.exs` | Tests for Node behavior |
| `apps/graph_os_graph/test/store/edge_test.exs` | Tests for Edge behavior |
| `apps/graph_os_graph/test/store/schema_test.exs` | Update existing schema tests |
| `apps/graph_os_graph/test/store/adapter/ets_test.exs` | Tests for ETS adapter |
| `apps/graph_os_graph/test/store/algorithm_test.exs` | Update existing algorithm tests |
| `apps/graph_os_graph/test/store/algorithm/ets_test.exs` | Update existing ETS algorithm tests |
| `apps/graph_os_core/test/access_test.exs` | Tests for Access module |
| `apps/graph_os_core/test/access/policy_test.exs` | Tests for Policy graph |
| `apps/graph_os_core/test/access/actor_test.exs` | Tests for Actor node |
| `apps/graph_os_core/test/access/scope_test.exs` | Tests for Scope node |
| `apps/graph_os_core/test/access/group_test.exs` | Tests for Group node |
| `apps/graph_os_core/test/access/restriction_test.exs` | Tests for Restriction edge |
| `apps/graph_os_core/test/access/membership_test.exs` | Tests for Membership edge |
| `apps/graph_os_core/test/access/permission_test.exs` | Tests for Permission edge |

4. **Test Files to Delete**

| Test File | Reason |
|-----------|--------|
| `apps/graph_os_graph/test/graph_test.exs` | Replaced by store_test.exs |
| `apps/graph_os_graph/test/graph/node_test.exs` | Replaced by store/node_test.exs |
| `apps/graph_os_graph/test/graph/edge_test.exs` | Replaced by store/edge_test.exs |

### 4.4 Migration Plan

1. **Phase 1: Core Infrastructure**
   - Start with `GraphOS.Store` and adapter implementation
   - Implement `GraphOS.Store.Schema` and refactor from existing
   - Implement `GraphOS.Store.Graph`, `GraphOS.Store.Node`, and `GraphOS.Store.Edge`
   - Update `GraphOS.Store.Algorithm` and ETS implementation to work with new API
   - Write tests for all core components

2. **Phase 2: Access Control Module**
   - Implement Access Policy graph
   - Implement Actor, Scope, Group nodes
   - Implement Permission, Membership, Restriction edges
   - Implement main Access module
   - Write tests for Access Control modules

3. **Phase 3: Other Core Modules**
   - Implement Files and other module graphs
   - Test cross-graph references and operations
   - Ensure proper Boundary integration across all modules

4. **Phase 4: Integration and Cleanup**
   - Remove deprecated modules and functions
   - Update documentation and examples
   - Ensure all tests pass with new implementation
   - Review and optimize performance

5. **Phase 5: Documentation & Examples**
   - Document the API
   - Create examples
   - Update README and docs

### 4.5 Compatibility Considerations

1. **Breaking Changes**
   - API changes from GraphOS.Graph to GraphOS.Store
   - Schema definition syntax changes
   - Edge and Node behavior changes
   - Update all code that uses the old Graph API

2. **Performance Monitoring**
   - Benchmark existing vs. new implementation
   - Optimize bottlenecks in cross-graph operations
   - Profile memory usage with large datasets

3. **Backward Compatibility Layer**
   - Consider providing an adapter layer for existing code
   - Deprecation warnings for old API usage
   - Migration guide for users

### 4.6 Special Considerations

1. **Boundary Enforcement**
   - Every module MUST have proper Boundary definitions
   - GraphOS.Core.Access.Policy must have zero dependencies to other graphs
   - Enforce proper layering of dependencies
   - Use Boundary compile-time checks to validate dependency structure

2. **Graph ID Management**
   - Access.Policy should be assigned ID 0 as the root graph
   - Ensure graph IDs are consistent across restarts
   - Consider using a named registry for graphs to ensure proper lookups

3. **Algorithm Optimization**
   - Ensure all existing algorithms work efficiently with the new structure
   - Optimize for cross-graph traversals
   - Implement special handling for large datasets

4. **Data Migration**
   - Provide helpers to migrate existing data to new format
   - Consider backward compatibility for existing clients
   - Test data migration thoroughly

5. **Error Handling and Logging**
   - Implement proper error handling throughout the API
   - Add detailed logging for debugging
   - Ensure clear error messages for common issues

This refactoring plan provides a detailed roadmap for implementing the new GraphOS.Store design while ensuring proper boundary enforcement, algorithm preservation, and comprehensive testing.

## 5. Comprehensive File Status List

This section provides a detailed list of all .ex files in the apps/graph_os_graph/ scope and their status in the refactoring.

### 5.1 Main Library Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/lib/graph.ex` | VERIFY/MODIFY | Update to new Store API or replace if exists |
| `apps/graph_os_graph/lib/store.ex` | CREATE | New main entrypoint for Store API |
| `apps/graph_os_graph/lib/store/schema.ex` | UPDATE | Update to support new schema DSL |
| `apps/graph_os_graph/lib/store/schema_behaviour.ex` | UPDATE | Update to align with new schema integration |
| `apps/graph_os_graph/lib/store/graph.ex` | CREATE | New Graph behavior definition |
| `apps/graph_os_graph/lib/store/node.ex` | CREATE | New Node behavior definition |
| `apps/graph_os_graph/lib/store/edge.ex` | CREATE | New Edge behavior definition |
| `apps/graph_os_graph/lib/store/transaction.ex` | CREATE | New transaction handling module |
| `apps/graph_os_graph/lib/store/query.ex` | CREATE | New query builder module |

### 5.2 Algorithm Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/lib/store/algorithm.ex` | UPDATE | Update API calls to use new Store interface and support cross-graph operations |
| `apps/graph_os_graph/lib/store/algorithm/ets.ex` | UPDATE | Update to work with new ETS adapter |

> **Note**: With our design of using a single table for all nodes with a graph_id field, cross-graph operations are inherently supported without needing specialized algorithms. Regular graph algorithms can be modified to filter (or not) based on graph_id.

### 5.3 Adapter Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/lib/store/adapter.ex` | CREATE | Adapter behavior definition |
| `apps/graph_os_graph/lib/store/adapter/ets.ex` | CREATE | ETS adapter implementation |
| `apps/graph_os_graph/lib/store/adapter/registry.ex` | CREATE | Registry for store adapters |

### 5.4 Protobuf Integration Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/lib/store/schema/protobuf.ex` | UPDATE/CREATE | Update if exists, create if not |
| `apps/graph_os_graph/lib/store/schema/converter.ex` | UPDATE/CREATE | Update if exists, create if not |

### 5.5 Test Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/test/store_test.exs` | CREATE | New tests for Store API |
| `apps/graph_os_graph/test/store/graph_test.exs` | CREATE | Tests for Graph behavior |
| `apps/graph_os_graph/test/store/node_test.exs` | CREATE | Tests for Node behavior |
| `apps/graph_os_graph/test/store/edge_test.exs` | CREATE | Tests for Edge behavior |
| `apps/graph_os_graph/test/store/schema_test.exs` | UPDATE/CREATE | Update if exists, create if not |
| `apps/graph_os_graph/test/store/schema_behaviour_test.exs` | UPDATE/CREATE | Update if exists, create if not |
| `apps/graph_os_graph/test/store/transaction_test.exs` | CREATE | Tests for transaction handling |
| `apps/graph_os_graph/test/store/query_test.exs` | CREATE | Tests for query builder |
| `apps/graph_os_graph/test/store/adapter/ets_test.exs` | CREATE | Tests for ETS adapter |
| `apps/graph_os_graph/test/store/algorithm_test.exs` | UPDATE/CREATE | Update if exists, create if not |
| `apps/graph_os_graph/test/store/algorithm/ets_test.exs` | UPDATE/CREATE | Update if exists, create if not |

### 5.6 Support Files

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_graph/lib/store/helpers.ex` | CREATE | Helper functions for store operations |
| `apps/graph_os_graph/lib/store/errors.ex` | CREATE | Error types and handling |
| `apps/graph_os_graph/lib/store/macros.ex` | CREATE | Macros for DSL implementation |
| `apps/graph_os_graph/mix.exs` | UPDATE | Update application configuration |
| `apps/graph_os_graph/README.md` | UPDATE | Update documentation |

### 5.7 Core Module Implementation (in graph_os_core)

| File Path | Status | Notes |
|-----------|--------|-------|
| `apps/graph_os_core/lib/access/policy.ex` | CREATE | Access Policy graph |
| `apps/graph_os_core/lib/access/actor.ex` | CREATE | Actor node |
| `apps/graph_os_core/lib/access/scope.ex` | CREATE | Scope node |
| `apps/graph_os_core/lib/access/group.ex` | CREATE | Group node |
| `apps/graph_os_core/lib/access/restriction.ex` | CREATE | Restriction edge |
| `apps/graph_os_core/lib/access/membership.ex` | CREATE | Membership edge |
| `apps/graph_os_core/lib/access/permission.ex` | CREATE | Permission edge |
| `apps/graph_os_core/lib/access.ex` | CREATE | Main Access module |
| `apps/graph_os_core/lib/files/graph.ex` | CREATE | Files graph |
| `apps/graph_os_core/lib/files/file.ex` | CREATE | File node |

This comprehensive example shows how the entire Access Control system works together, with proper edge restrictions, schema validation, and cross-graph references.

### 5.8 Implementation Note

Before starting implementation, it's recommended to run `find apps/graph_os_graph -type f -name "*.ex"` to get a complete list of all existing .ex files in the codebase. This will help ensure that all existing files are properly accounted for in the refactoring plan. Some files listed here may not exist yet, or might have different names in the actual codebase.


