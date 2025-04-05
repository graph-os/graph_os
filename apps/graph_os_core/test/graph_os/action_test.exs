defmodule GraphOS.ActionTest do
  use ExUnit.Case, async: true

  # No Mox needed
  # import Mox

  alias GraphOS.Core.FileSystem.File, as: TestFileComponent
  # No FileSystem double needed now
  # alias GraphOS.Core.FileSystemMock, as: TestFileSystemGraph

  # Mock Conn struct (replace with actual struct if available)
  defmodule MockConn do
    defstruct actor_id: "test_actor"
  end

  # Mock File node struct (replace with actual struct if available)
  # Note: Using the real struct now, so this isn't strictly needed unless
  # the real struct isn't defined yet by `use GraphOS.Entity.Node`
  defmodule MockFileNode do
     defstruct id: "file_scope_id_123", path: nil, data: %{} # Add other fields as needed
  end

  # Setup mocks and test-specific entities within the store
  setup do
    # Start a unique store for *each* test
    store_name = :"#{__MODULE__}_#{System.unique_integer([:positive])}" # Match access_test pattern
    {:ok, _pid} = GraphOS.Store.start_link(name: store_name)
    # Ensure store is stopped when the test finishes
    on_exit(fn -> GraphOS.Store.stop(store_name) end)

    # Setup required Access entities for the test using the new store_name
    actor_id = "actor-reader-#{System.unique_integer([:positive])}"
    policy_id = "test_policy" # Define a policy ID for the test
    # Create actor within the policy and store, using the local store_name
    {:ok, _actor} = GraphOS.Access.create_actor(store_name, policy_id, %{id: actor_id, name: "Test Reader"})

    # No Mox expectations needed

    # Return context needed by the test
    {:ok, %{store_ref: store_name, test_actor_id: actor_id, test_policy_id: policy_id}}
  end

  test "executing a :read action successfully with wait", %{store_ref: store_ref, test_actor_id: actor_id, test_policy_id: policy_id} do
    # 1. Setup - Create a temporary file, File node, Access Scope/Permissions
    temp_dir = System.tmp_dir!()
    temp_file_path = Path.join(temp_dir, "graphos_action_test_#{System.unique_integer([:positive])}.txt")
    file_content = "Hello Real Access!"
    :ok = File.write(temp_file_path, file_content)

    # Ensure file cleanup
    on_exit(fn -> File.rm(temp_file_path) end)

    # Define the ID based on path, used for both Scope and Node in this test
    scope_id = "file-scope-#{temp_file_path |> Path.basename() |> String.replace(~r/[^a-zA-Z0-9]/, "-")}"

    # Create scope and grant permission FIRST
    {:ok, _scope} = GraphOS.Access.create_scope(store_ref, policy_id, %{id: scope_id, name: "Test File Scope #{scope_id}"})
    {:ok, _perm} = GraphOS.Access.grant_permission(store_ref, policy_id, scope_id, actor_id, %{execute: true})

    # Create a real File node entity in the store AFTER scope/permission
    # Use a *distinct* ID for the node itself
    node_id = "node-#{scope_id}"
    file_node_data = %{path: temp_file_path, some_other_data: "test"}
    # Use the actual TestFileComponent module (which is File) for insertion
    {:ok, file_node} = GraphOS.Store.insert(store_ref, TestFileComponent, %{id: node_id, data: file_node_data})


    # 2. Prepare arguments
    mock_conn = %MockConn{actor_id: actor_id} # Use actor_id from context
    # Payload needs to include the scope_id for authorization check,
    # alongside the node and operation details.
    # Format: {node_struct, scope_id_for_auth, operation_atom, operation_args}
    operation_args = %{"path" => temp_file_path} # Still needed for do_read
    payload = {file_node, scope_id, :read, operation_args}
    opts = [wait: 2000] # Keep wait option

    # 3. Execute the action via the component's entry point, passing store_ref positionally
    result = TestFileComponent.execute(store_ref, mock_conn, payload, opts)

    # 4. Assertions
    assert {:ok, status_map} = result
    assert status_map.status == :completed
    assert status_map.result == {:ok, file_content} # File.read returns {:ok, content}
    assert status_map.error == nil
    assert is_struct(status_map.started_at, DateTime)
    assert is_struct(status_map.finished_at, DateTime)
  end

  # TODO: Add tests for:
  # - Authorization failure
  # - Validation failure (e.g., missing required args for :write)
  # - :write action
  # - Fully async execution (wait: 0) and polling with get_status
  # - Error during do_operation (e.g., file not found for read)
  # - Invalid payload format in execute/3
end
