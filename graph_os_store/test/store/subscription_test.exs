defmodule GraphOS.Store.SubscriptionTest do
  @moduledoc """
  Tests for the GraphOS.Store subscription API.
  """
  
  use ExUnit.Case, async: false
  
  alias GraphOS.Store
  alias GraphOS.Store.Event
  alias GraphOS.Store.Subscription
  
  setup do
    # Start a dedicated test store
    store_name = :subscription_test_store
    {:ok, _pid} = Store.start_link(name: store_name)
    
    # Clean up after each test
    on_exit(fn ->
      Store.stop(store_name)
    end)
    
    # Return the store name to the test
    {:ok, %{store: store_name}}
  end
  
  describe "basic subscription functionality" do
    test "can subscribe to node events", %{store: store} do
      # Subscribe to all node events
      {:ok, sub_id} = Store.subscribe(store, :node)
      assert is_binary(sub_id)
      
      # Check that subscription is listed
      {:ok, subscriptions} = Store.list_subscriptions(store)
      assert length(subscriptions) == 1
      assert hd(subscriptions).id == sub_id
      assert hd(subscriptions).topic == :node
    end
    
    test "can unsubscribe from events", %{store: store} do
      # Subscribe and then unsubscribe
      {:ok, sub_id} = Store.subscribe(store, :node)
      assert is_binary(sub_id)
      
      :ok = Store.unsubscribe(store, sub_id)
      
      # Check that subscription is gone
      {:ok, subscriptions} = Store.list_subscriptions(store)
      assert Enum.empty?(subscriptions)
    end
    
    test "can subscribe to specific event types", %{store: store} do
      # Subscribe only to create events
      {:ok, sub_id} = Store.subscribe(store, :node, events: [:create])
      
      # Check that subscription has correct filters
      {:ok, subscriptions} = Store.list_subscriptions(store)
      assert length(subscriptions) == 1
      assert hd(subscriptions).filters.events == [:create]
    end
  end
  
  describe "event delivery" do
    test "receives events for matching subscriptions", %{store: store} do
      # Subscribe to node creation events
      {:ok, _} = Store.subscribe(store, :node, events: [:create])
      
      # Create a test event
      event = Event.create(:node, "test123", %{type: "person", data: %{name: "Test"}})
      
      # Publish the event
      :ok = Store.publish(store, event)
      
      # Check if we received the event
      assert_receive {:graph_os_store, :node, received_event}, 1000
      assert received_event.entity_id == "test123"
      assert received_event.type == :create
    end
    
    test "filtering works correctly", %{store: store} do
      # Subscribe to node creation events for 'person' type only
      {:ok, _} = Store.subscribe(store, :node, events: [:create], filter: %{entity_type: :node})
      
      # Create two test events - one matching, one not matching
      matching_event = Event.create(:node, "person123", %{type: "person"})
      non_matching_event = Event.create(:edge, "edge123", %{type: "knows"})
      
      # Publish both events
      :ok = Store.publish(store, matching_event)
      :ok = Store.publish(store, non_matching_event)
      
      # We should only receive the matching event
      assert_receive {:graph_os_store, :node, received_event}, 1000
      assert received_event.entity_id == "person123"
      
      # Make sure we didn't receive the non-matching event
      refute_receive {:graph_os_store, :edge, _}, 100
    end
  end
  
  describe "topic matching" do
    test "exact topic matching works", %{store: store} do
      # Subscribe to a specific topic
      {:ok, _} = Store.subscribe(store, "user:login")
      
      # Create and publish an event with matching topic
      event = Event.custom("user:login", :node, "user123", metadata: %{ip: "127.0.0.1"})
      :ok = Store.publish(store, event)
      
      # Check if we received the event
      assert_receive {:graph_os_store, "user:login", _}, 1000
    end
    
    test "entity type pattern matching works", %{store: store} do
      # Subscribe to node events of type "person"
      {:ok, _} = Store.subscribe(store, {:node, "person"})
      
      # Create and publish events - one matching, one not
      matching_event = Event.create(:node, "person123", %{type: "person"})
      non_matching_event = Event.create(:node, "doc123", %{type: "document"})
      
      # Publish both events
      Store.publish(store, matching_event)
      Store.publish(store, non_matching_event)
      
      # We should only receive events for the matching pattern
      assert_receive {:graph_os_store, :node, received_event}, 1000
      assert received_event.entity_id == "person123"
    end
  end
end
