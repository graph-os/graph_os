defmodule GraphOS.Component.ContextTest do
  use ExUnit.Case, async: true
  alias GraphOS.Component.Context

  describe "new/1" do
    test "creates a new context with default values" do
      context = Context.new()
      assert context.assigns == %{}
      assert context.halted == false
      assert context.params == %{}
      assert is_binary(context.request_id)
      assert context.result == nil
      assert context.error == nil
      assert context.metadata == %{}
      assert context.private == %{}
    end

    test "creates a new context with provided values" do
      context =
        Context.new(
          params: %{name: "test"},
          request_id: "custom-id",
          metadata: %{source: :test}
        )

      assert context.params == %{name: "test"}
      assert context.request_id == "custom-id"
      assert context.metadata == %{source: :test}
    end
  end

  describe "assign/3" do
    test "adds a value to assigns" do
      context = Context.new() |> Context.assign(:user_id, 123)
      assert context.assigns.user_id == 123
    end
  end

  describe "assign/2" do
    test "adds multiple values to assigns from keyword list" do
      context = Context.new() |> Context.assign(user_id: 123, role: :admin)
      assert context.assigns == %{user_id: 123, role: :admin}
    end

    test "adds multiple values to assigns from map" do
      context = Context.new() |> Context.assign(%{user_id: 123, role: :admin})
      assert context.assigns == %{user_id: 123, role: :admin}
    end

    test "merges with existing assigns" do
      context =
        Context.new()
        |> Context.assign(:user_id, 123)
        |> Context.assign(role: :admin, team: "engineering")

      assert context.assigns == %{user_id: 123, role: :admin, team: "engineering"}
    end
  end

  describe "put_result/2" do
    test "stores a result in the context" do
      result = %{data: [1, 2, 3]}
      context = Context.new() |> Context.put_result(result)
      assert context.result == result
    end

    test "clears any existing error" do
      context =
        Context.new()
        |> Context.put_error(:not_found, "Not found")
        |> Context.put_result(%{data: [1, 2, 3]})

      assert context.error == nil
      assert context.result == %{data: [1, 2, 3]}
    end
  end

  describe "put_error/3" do
    test "stores an error in the context and halts by default" do
      context = Context.new() |> Context.put_error(:not_found, "Resource not found")
      assert context.error == {:not_found, "Resource not found"}
      assert context.halted == true
    end

    test "stores an error without halting when halt: false" do
      context = Context.new() |> Context.put_error(:validation, "Invalid input", halt: false)
      assert context.error == {:validation, "Invalid input"}
      assert context.halted == false
    end
  end

  describe "halt/1" do
    test "marks the context as halted" do
      context = Context.new() |> Context.halt()
      assert context.halted == true
    end
  end

  describe "halted?/1" do
    test "returns false for non-halted contexts" do
      context = Context.new()
      refute Context.halted?(context)
    end

    test "returns true for halted contexts" do
      context = Context.new() |> Context.halt()
      assert Context.halted?(context)
    end
  end

  describe "put_private/3" do
    test "adds a value to private" do
      context = Context.new() |> Context.put_private(:auth_token, "abc123")
      assert context.private.auth_token == "abc123"
    end
  end

  describe "put_private/2" do
    test "adds multiple values to private" do
      context = Context.new() |> Context.put_private(auth_token: "abc123", session_id: "xyz")
      assert context.private == %{auth_token: "abc123", session_id: "xyz"}
    end

    test "merges with existing private values" do
      context =
        Context.new()
        |> Context.put_private(:auth_token, "abc123")
        |> Context.put_private(session_id: "xyz", user_agent: "test")

      assert context.private == %{auth_token: "abc123", session_id: "xyz", user_agent: "test"}
    end
  end

  describe "put_metadata/3" do
    test "adds a value to metadata" do
      context = Context.new() |> Context.put_metadata(:timestamp, 1_615_000_000)
      assert context.metadata.timestamp == 1_615_000_000
    end
  end

  describe "put_metadata/2" do
    test "adds multiple values to metadata" do
      context = Context.new() |> Context.put_metadata(timestamp: 1_615_000_000, source: :api)
      assert context.metadata == %{timestamp: 1_615_000_000, source: :api}
    end

    test "merges with existing metadata" do
      context =
        Context.new()
        |> Context.put_metadata(:timestamp, 1_615_000_000)
        |> Context.put_metadata(source: :api, ip: "127.0.0.1")

      assert context.metadata == %{timestamp: 1_615_000_000, source: :api, ip: "127.0.0.1"}
    end
  end

  describe "error?/1" do
    test "returns false when there is no error" do
      context = Context.new()
      refute Context.error?(context)
    end

    test "returns true when there is an error" do
      context = Context.new() |> Context.put_error(:not_found, "Resource not found")
      assert Context.error?(context)
    end
  end

  describe "error/1" do
    test "returns nil when there is no error" do
      context = Context.new()
      assert Context.error(context) == nil
    end

    test "returns the error tuple when there is an error" do
      context = Context.new() |> Context.put_error(:not_found, "Resource not found")
      assert Context.error(context) == {:not_found, "Resource not found"}
    end
  end
end
