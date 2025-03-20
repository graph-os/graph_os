defmodule GraphOS.GraphContext.Subscription do
  @moduledoc """
  Behaviour defining the graph subscription interface.

  This module defines the contract for subscription implementations that can be
  used with GraphOS.GraphContext. It allows components to be notified of graph changes
  without coupling the graph library to a specific pub/sub implementation.

  ## Usage

  Implement this behaviour in your subscription module:

  ```elixir
  defmodule MyGraphSubscription do
    @behaviour GraphOS.GraphContext.Subscription

    @impl true
    def subscribe(topic, opts) do
      # Your subscription implementation
      {:ok, subscription_id}
    end

    # Implement other callback functions...
  end
  ```

  Then pass the module to your application:

  ```elixir
  GraphOS.Core.configure(subscription_module: MyGraphSubscription)
  ```

  ## Events

  The following topics and event types are defined:

  - `"node:\#{node_id}"` - Events for a specific node
    - `{:node_created, node}`
    - `{:node_updated, node, changes}`
    - `{:node_deleted, node_id}`

  - `"edge:\#{edge_id}"` - Events for a specific edge
    - `{:edge_created, edge}`
    - `{:edge_updated, edge, changes}`
    - `{:edge_deleted, edge_id}`

  - `"graph"` - Graph-wide events
    - `{:transaction_committed, transaction_id, operations}`
    - `{:transaction_rolled_back, transaction_id}`

  - `"query:\#{pattern}"` - Query-matching events
    - `{:node_matched, node, pattern}` - When a node matching a pattern is changed
    - `{:edge_matched, edge, pattern}` - When an edge matching a pattern is changed
  """

  alias GraphOS.GraphContext.{Node, Edge, Operation}

  @type topic :: String.t()
  @type subscription_id :: reference()
  @type pattern :: String.t()
  @type event ::
    {:node_created, Node.t()} |
    {:node_updated, Node.t(), map()} |
    {:node_deleted, Node.id()} |
    {:edge_created, Edge.t()} |
    {:edge_updated, Edge.t(), map()} |
    {:edge_deleted, Edge.id()} |
    {:transaction_committed, reference(), list(Operation.t())} |
    {:transaction_rolled_back, reference()} |
    {:node_matched, Node.t(), pattern()} |
    {:edge_matched, Edge.t(), pattern()}

  @doc """
  Subscribe to events on a specific topic.

  ## Parameters

  - `topic` - The topic to subscribe to (e.g., "node:123", "edge:abc", "graph")
  - `opts` - Subscription options
    - `:subscriber` - The process to receive events (default: self())
    - Additional options specific to the implementation

  ## Returns

  - `{:ok, subscription_id}` - Successfully subscribed
  - `{:error, reason}` - Failed to subscribe
  """
  @callback subscribe(topic(), keyword()) :: {:ok, subscription_id()} | {:error, term()}

  @doc """
  Unsubscribe from a specific subscription.

  ## Parameters

  - `subscription_id` - The ID returned from subscribe/2

  ## Returns

  - `:ok` - Successfully unsubscribed
  - `{:error, reason}` - Failed to unsubscribe
  """
  @callback unsubscribe(subscription_id()) :: :ok | {:error, term()}

  @doc """
  Broadcast an event to all subscribers of a topic.

  ## Parameters

  - `topic` - The topic to broadcast to
  - `event` - The event to broadcast

  ## Returns

  - `:ok` - Event broadcast successfully
  - `{:error, reason}` - Failed to broadcast
  """
  @callback broadcast(topic(), event()) :: :ok | {:error, term()}

  @doc """
  Create a subscription ID for a pattern-based query.

  This allows subscribing to nodes or edges that match specific patterns,
  rather than specific IDs.

  ## Parameters

  - `pattern` - A pattern specification
  - `opts` - Options specific to the pattern type

  ## Returns

  - `{:ok, topic}` - The topic to subscribe to
  - `{:error, reason}` - Failed to create pattern topic
  """
  @callback pattern_topic(pattern(), keyword()) :: {:ok, topic()} | {:error, term()}

  @doc """
  Initialize the subscription system.

  ## Parameters

  - `opts` - Options specific to the implementation

  ## Returns

  - `:ok` - Successfully initialized
  - `{:error, reason}` - Failed to initialize
  """
  @callback init(keyword()) :: :ok | {:error, term()}
end
