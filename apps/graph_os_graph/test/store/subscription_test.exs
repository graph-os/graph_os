defmodule GraphOS.Store.SubscriptionTest do
  # Set async: false since we're using a named GenServer
  use ExUnit.Case, async: false

  alias GraphOS.Store.Subscription

  setup do
    # Start the GenServer before each test
    start_supervised!(Subscription)
    :ok
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
end
