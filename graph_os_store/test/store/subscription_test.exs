defmodule GraphOS.Store.SubscriptionTest do
  # Set async: false since we're using a named GenServer
  use ExUnit.Case, async: false

  alias GraphOS.Store.Subscription
  alias GraphOS.Store
  alias GraphOS.Store.Event

  setup do
    # Start the GenServer before each test
    start_supervised!(Subscription)
    # Start a store for testing
    {:ok, store} = Store.init(table_prefix: "subscription_test_")
    on_exit(fn -> Store.stop(store) end)
    %{store: store}
  end

  # Test the Subscription subscription implementation (default implementation)
  describe "Subscription subscription implementation" do
    test "subscribe/2 always returns success with reference" do
      result = Subscription.subscribe("test_topic", [])
      assert {:ok, subscription_id} = result
      assert is_reference(subscription_id)
    end

    test "unsubscribe/1 always returns ok" do
      {:ok, subscription_id} = Subscription.subscribe("test_topic", [])
      assert :ok = Subscription.unsubscribe(subscription_id)
    end

    test "broadcast/2 always returns ok" do
      assert :ok = Subscription.broadcast("test_topic", {:node_created, %{id: "test_node"}})
    end

    test "pattern_topic/2 returns a valid topic" do
      {:ok, topic} = Subscription.pattern_topic("test_pattern", [])
      assert is_binary(topic)
      assert String.starts_with?(topic, "pattern:")
    end

    test "initialize/1 returns ok" do
      assert :ok = Subscription.initialize([])
    end
  end

  # Test the subscription interface to ensure it defines the required callbacks
  describe "Subscription behaviour" do
    test "defines the expected callbacks via implementation" do
      # We'll verify that the behaviour exists by checking that our implementation
      # successfully uses the @behaviour attribute and implements all the required callbacks

      # Check that the Subscription module implements the Subscription behaviour
      assert Code.ensure_loaded?(GraphOS.Store.Subscription)

      # Check that Subscription implements all the required callbacks of the behaviour
      assert function_exported?(GraphOS.Store.Subscription, :subscribe, 2)
      assert function_exported?(GraphOS.Store.Subscription, :unsubscribe, 1)
      assert function_exported?(GraphOS.Store.Subscription, :broadcast, 2)
      assert function_exported?(GraphOS.Store.Subscription, :pattern_topic, 2)
      assert function_exported?(GraphOS.Store.Subscription, :initialize, 1)
    end
  end

  # Custom test subscription module to verify correct use of the behavior
  defmodule TestSubscription do
    @behaviour GraphOS.Store.SubscriptionBehaviour

    # Track calls to the subscription functions
    def start_link do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def calls do
      Agent.get(__MODULE__, & &1)
    end

    def record_call(function, args) do
      Agent.update(__MODULE__, fn calls -> [{function, args} | calls] end)
    end

    @impl true
    def subscribe(topic, opts) do
      record_call(:subscribe, [topic, opts])
      {:ok, make_ref()}
    end

    @impl true
    def unsubscribe(subscription_id) do
      record_call(:unsubscribe, [subscription_id])
      :ok
    end

    @impl true
    def broadcast(topic, event) do
      record_call(:broadcast, [topic, event])
      :ok
    end

    @impl true
    def pattern_topic(pattern, opts) do
      record_call(:pattern_topic, [pattern, opts])
      {:ok, "query:#{pattern}"}
    end

    @impl true
    def initialize(opts) do
      record_call(:initialize, [opts])
      :ok
    end
  end

  describe "Custom subscription implementation" do
    setup do
      {:ok, _pid} = TestSubscription.start_link()
      :ok
    end

    test "can be used to implement the subscription behaviour" do
      # Use the custom implementation
      {:ok, sub_id} = TestSubscription.subscribe("test_topic", subscriber: self())
      :ok = TestSubscription.unsubscribe(sub_id)
      :ok = TestSubscription.broadcast("test_topic", {:node_created, %{id: "test"}})
      {:ok, _} = TestSubscription.pattern_topic("name:foo*", [])
      :ok = TestSubscription.initialize([])

      # Verify all calls were recorded
      calls = TestSubscription.calls()
      assert Enum.any?(calls, fn {func, _} -> func == :subscribe end)
      assert Enum.any?(calls, fn {func, _} -> func == :unsubscribe end)
      assert Enum.any?(calls, fn {func, _} -> func == :broadcast end)
      assert Enum.any?(calls, fn {func, _} -> func == :pattern_topic end)
      assert Enum.any?(calls, fn {func, _} -> func == :initialize end)
    end
  end

  describe "subscription API" do
    test "subscribe and receive events for node creation", %{store: store} do
      # Subscribe to all node events
      {:ok, subscription_id} = Store.subscribe(:node, store: store)

      # Create a node
      {:ok, node} = Store.insert(:node, %{data: %{name: "Test Node"}}, store: store)

      # Wait for the event
      assert_receive {:graph_os_store, topic, event}, 1000
      assert topic =~ "pattern:node"
      assert event.type == :create
      assert event.entity_type == :node
      assert event.entity_id == node.id
      assert event.entity == node

      # Clean up
      Store.unsubscribe(subscription_id, store: store)
    end

    test "subscribe to specific node events", %{store: store} do
      # Create a node first
      {:ok, node} = Store.insert(:node, %{data: %{name: "Specific Node"}}, store: store)

      # Subscribe to specific node events
      {:ok, subscription_id} = Store.subscribe({:node, node.id}, store: store)

      # Update the node
      {:ok, updated_node} = Store.update(:node, %{id: node.id, data: %{name: "Updated Node"}}, store: store)

      # Wait for the event
      assert_receive {:graph_os_store, topic, event}, 1000
      assert topic =~ "pattern:node:#{node.id}"
      assert event.type == :update
      assert event.entity_type == :node
      assert event.entity_id == node.id
      assert event.entity == updated_node
      assert event.previous == node
      assert event.changes[:data][:name] == "Updated Node"

      # Delete the node
      :ok = Store.delete(:node, node.id, store: store)

      # Wait for the delete event
      assert_receive {:graph_os_store, topic, event}, 1000
      assert topic =~ "pattern:node:#{node.id}"
      assert event.type == :delete
      assert event.entity_type == :node
      assert event.entity_id == node.id
      assert event.entity == nil
      assert event.previous != nil

      # Clean up
      Store.unsubscribe(subscription_id, store: store)
    end

    test "subscribe to custom topics", %{store: store} do
      # Subscribe to a custom topic
      {:ok, subscription_id} = Store.subscribe("custom:login", store: store)

      # Create a custom event
      custom_event = Event.new(%{
        type: :custom,
        topic: "custom:login",
        entity_type: :node,
        entity_id: "user123",
        metadata: %{ip_address: "192.168.1.1"}
      })

      # Publish the event
      :ok = Store.publish(custom_event, store: store)

      # Wait for the event
      assert_receive {:graph_os_store, "custom:login", event}, 1000
      assert event.type == :custom
      assert event.topic == "custom:login"
      assert event.metadata.ip_address == "192.168.1.1"

      # Clean up
      Store.unsubscribe(subscription_id, store: store)
    end

    test "unsubscribe stops receiving events", %{store: store} do
      # Subscribe to all node events
      {:ok, subscription_id} = Store.subscribe(:node, store: store)

      # Create a node
      {:ok, node} = Store.insert(:node, %{data: %{name: "Test Node"}}, store: store)

      # Wait for the event
      assert_receive {:graph_os_store, _topic, _event}, 1000

      # Unsubscribe
      :ok = Store.unsubscribe(subscription_id, store: store)

      # Create another node - we shouldn't receive this event
      {:ok, _node2} = Store.insert(:node, %{data: %{name: "Second Node"}}, store: store)

      # Make sure we don't receive the event for the second node
      refute_receive {:graph_os_store, _topic, _event}, 500
    end

    test "subscriber process termination automatically unsubscribes", %{store: store} do
      # Start a process that will subscribe and then terminate
      task = Task.async(fn ->
        {:ok, _subscription_id} = Store.subscribe(:node, store: store)
        # Just return the task PID for verification
        self()
      end)

      # Wait for the task to complete and get its PID
      subscriber_pid = Task.await(task)

      # Give the subscription system time to detect the process termination
      :timer.sleep(100)

      # Create a node - the subscriber's termination should have unsubscribed it
      {:ok, _node} = Store.insert(:node, %{data: %{name: "Test Node"}}, store: store)

      # Verify the subscriber was removed from the subscription registry
      # We'll need to access the state of the Subscription server for this
      registry_state = :sys.get_state(GraphOS.Store.Subscription)

      # Check that there are no more subscribers for the topic
      assert Map.get(registry_state.subscribers, "pattern:node", []) == [] or
             not Enum.member?(Map.get(registry_state.subscribers, "pattern:node", []), subscriber_pid)
    end
  end
end
