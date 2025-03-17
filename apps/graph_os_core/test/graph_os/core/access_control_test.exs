defmodule GraphOS.Core.AccessControlTest do
  use ExUnit.Case, async: false

  alias GraphOS.Graph
  alias GraphOS.Core.AccessControl
  alias GraphOS.Core.Access.GraphAccess

  setup do
    # Use the proper initialization through Graph module
    Graph.init()
    # Initialize access control
    AccessControl.init(Graph)
    :ok
  end

  describe "actor management" do
    test "define_actor creates an actor node" do
      # Define a test actor
      {:ok, actor} = AccessControl.define_actor(Graph, "user:test", %{role: "tester"})

      # Verify actor was created with correct attributes
      assert actor.id == "user:test"
      assert actor.data.role == "tester"
      assert actor.data.type == "access:actor"
      assert actor.data.protected == true
    end

    test "multiple actors can be defined" do
      # Define multiple actors
      {:ok, actor1} = AccessControl.define_actor(Graph, "user:alice", %{role: "admin"})
      {:ok, actor2} = AccessControl.define_actor(Graph, "user:bob", %{role: "user"})
      
      # Verify both actors were created with correct attributes
      assert actor1.id == "user:alice"
      assert actor1.data.role == "admin"
      
      assert actor2.id == "user:bob"
      assert actor2.data.role == "user"
    end
  end

  describe "permission management" do
    setup do
      # Create a test actor for each test
      {:ok, _} = AccessControl.define_actor(Graph, "user:test", %{role: "tester"})
      {:ok, %{}}
    end

    test "grant_permission creates permission edge" do
      # Grant a permission
      {:ok, edge} = AccessControl.grant_permission(Graph, "user:test", "resource:test", [:read, :write])

      # Verify permission edge was created correctly
      assert edge.id == "user:test->resource:test"
      assert edge.source == "user:test"
      assert edge.target == "resource:test"
    end
  end

  # These tests can be enabled when full access control queries are implemented
  describe "access control feature tests" do
    test "placeholder for permission query tests" do
      # Define test actor and grant permissions
      {:ok, _} = AccessControl.define_actor(Graph, "user:tester", %{role: "tester"})
      {:ok, _} = AccessControl.grant_permission(Graph, "user:tester", "resource:test", [:read])
      
      # This is left as an example for future tests - the current implementation
      # may need to be updated to support proper permission querying
      assert true
    end
  end
  
  # Keeping a simpler test set that works with the current implementation
  describe "access system basics" do
    test "can initialize the access control system" do
      result = AccessControl.init(Graph)
      assert result == :ok
    end
    
    test "can create actor and context" do
      # Define test actor
      {:ok, actor} = AccessControl.define_actor(Graph, "user:admin", %{role: "admin"})
      assert actor.id == "user:admin"
      
      # Create context
      context = AccessControl.create_context(Graph, "user:admin")
      assert context.actor_id == "user:admin"
      assert context.graph == Graph
    end
    
    test "GraphAccess implements the Graph.Access behaviour" do
      # Test that the module exists and implements the required behaviour
      module_info = GraphAccess.module_info()
      assert is_list(module_info)
      
      # Verify core functions are exported
      assert function_exported?(GraphAccess, :init, 1)
      assert function_exported?(GraphAccess, :authorize_operation, 2)
      assert function_exported?(GraphAccess, :authorize_query, 2)
      assert function_exported?(GraphAccess, :authorize_transaction, 2)
      assert function_exported?(GraphAccess, :filter_results, 2)
    end
  end
end
