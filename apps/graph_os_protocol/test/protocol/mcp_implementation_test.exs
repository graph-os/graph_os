require GraphOS.GraphContext.Action # Added require
defmodule GraphOS.Protocol.MCPImplementationTest do
  use ExUnit.Case, async: true

  alias GraphOS.Protocol.MCPImplementation
  alias GraphOS.Components.Registry
  alias GraphOS.GraphContext.Action # Needed for TestComponent Actions

  # --- Test Component Definition ---
  # Define a simple component specifically for these tests
  defmodule TestComponent do
    @moduledoc false
    defmodule Actions do
      @moduledoc false
      use GraphOS.GraphContext.Action

      action :test_action, input: [:input_data], output: :result_map
      action :action_that_errors, output: :error_reason

      @impl true
      def call(_conn, params, %{action: :test_action}) do
        # Simple action: return the received parameters wrapped in a standard structure
        {:ok, %{status: "success", received_params: params}}
      end

      @impl true
      def call(_conn, _params, %{action: :action_that_errors}) do
        # Action that simulates a failure
        {:error, :simulated_action_error}
      end

      # Default implementation for other actions if needed
      def call(_conn, _params, _opts), do: {:error, :action_not_implemented}
    end

    def __graphos_component__ do
      %{
        name: "test_component",
        actions_module: Actions,
        actions: [:test_action, :action_that_errors],
        queries: [] # No queries defined for this test component
      }
    end
  end
  # --- End Test Component Definition ---

  setup do
    # Ensure graph_os_core is started for the Registry
    Application.ensure_all_started(:graph_os_core)
    # Register the test component before each test
    Registry.register_component(TestComponent)

    # Return the component name for use in tests
    %{component_name: "test_component"}
  end

  describe "handle_tool_call/4 for execute_action" do
    test "successfully executes a registered action", %{component_name: component_name} do
      session_id = "test-session-1"
      request_id = "req-1"
      tool_name = "execute_action"
      action_name = "test_action"
      input_params = %{"input_data" => "hello world"}

      arguments = %{
        "component_name" => component_name,
        "action_name" => Atom.to_string(action_name),
        "params" => input_params
      }

      expected_result_data = %{status: "success", received_params: input_params}
      expected_content_text = Jason.encode!(expected_result_data, pretty: true)

      assert {:ok, %{content: [%{type: "text", text: ^expected_content_text}]}} =
               MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)
    end

    test "returns error for non-existent action", %{component_name: component_name} do
      session_id = "test-session-2"
      request_id = "req-2"
      tool_name = "execute_action"
      action_name = "non_existent_action"
      input_params = %{}

      arguments = %{
        "component_name" => component_name,
        "action_name" => action_name,
        "params" => input_params
      }

      # Expecting the Registry to return :action_not_found or similar
      assert {:error, %{code: :internal_error, message: _}} =
               MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)
      # Note: The exact error message might depend on Registry.execute_action implementation detail
    end

    test "returns error when action itself returns an error", %{component_name: component_name} do
      session_id = "test-session-3"
      request_id = "req-3"
      tool_name = "execute_action"
      action_name = "action_that_errors"
      input_params = %{}

      arguments = %{
        "component_name" => component_name,
        "action_name" => Atom.to_string(action_name),
        "params" => input_params
      }

      assert {:error, %{code: :internal_error, message: "Action failed: :simulated_action_error"}} =
               MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)
    end

    test "returns error for invalid action name format (non-atom string)", %{component_name: component_name} do
       session_id = "test-session-4"
       request_id = "req-4"
       tool_name = "execute_action"
       # Pass an integer or something else that String.to_atom will raise on
       action_name_invalid = 123

       arguments = %{
         "component_name" => component_name,
         "action_name" => action_name_invalid, # Invalid type
         "params" => %{}
       }

       assert {:error, %{code: :invalid_params, message: "Invalid action name: 123"}} =
                MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)
     end
  end

  describe "handle_tool_call/4 for query_graph" do
    # TODO: Add tests for query_graph once its implementation is finalized
    # These tests would likely require mocking the underlying query function
    # or setting up actual graph data.

    test "handles query_graph call (placeholder test)" do
      session_id = "test-session-q1"
      request_id = "req-q1"
      tool_name = "query_graph"
      query_path = "some.data.path"
      query_params = %{"filter" => "value"}

      arguments = %{
        "path" => query_path,
        "params" => query_params
      }

      # Current implementation returns a placeholder success
      expected_result = {:ok, %{query_path: query_path, received_params: query_params, note: "Query not implemented yet"}}
      expected_text = Jason.encode!(elem(expected_result, 1), pretty: true)

      assert {:ok, %{content: [%{type: "text", text: ^expected_text}]}} =
              MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)

      # Add assertions here once the query logic is implemented
      # assert result matches expected query output
    end
  end

  describe "handle_tool_call/4 for unknown tool" do
     test "returns error for unknown tool name" do
       session_id = "test-session-u1"
       request_id = "req-u1"
       tool_name = "unknown_tool_xyz"
       arguments = %{"some_arg" => "value"}

       assert {:error, %{code: :method_not_found, message: "Tool 'unknown_tool_xyz' not found."}} =
                MCPImplementation.handle_tool_call(session_id, request_id, tool_name, arguments)
     end
   end

end
