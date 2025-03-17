defmodule GraphOS.Graph.Subscription.NoOp do
  @moduledoc """
  A no-operation implementation of the GraphOS.Graph.Subscription behaviour.
  
  This module provides a minimal implementation of the Subscription interface
  that performs no actual subscription or broadcasting. It's useful for:
  
  1. Testing environments where notifications aren't needed
  2. Standalone usage of the graph library
  3. As a reference implementation for real subscription handlers
  
  All operations succeed but do nothing.
  """
  
  @behaviour GraphOS.Graph.Subscription
  
  @impl true
  def subscribe(_topic, _opts \\ [])
  
  def subscribe(_topic, _opts) do
    # Return a dummy subscription id
    {:ok, make_ref()}
  end
  
  @impl true
  def unsubscribe(_subscription_id) do
    # Always succeed but do nothing
    :ok
  end
  
  @impl true
  def broadcast(_topic, _event) do
    # Silently discard the event
    :ok
  end
  
  @impl true
  def pattern_topic(pattern, _opts \\ [])
  
  def pattern_topic(pattern, _opts) do
    # Return a standardized topic based on the pattern
    {:ok, "pattern:#{inspect(pattern)}"}
  end
  
  @impl true
  def init(_opts \\ [])
  
  def init(_opts) do
    # Always succeed
    :ok
  end
end