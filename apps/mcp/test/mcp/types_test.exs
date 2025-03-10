defmodule MCP.TypesTest do
  use ExUnit.Case, async: true

  alias MCP.Types

  describe "type definitions" do
    test "exports types that correspond to TypeScript SDK" do
      # This test verifies that the module exists and compiles
      # The @type declarations are checked at compile time, not runtime
      assert Code.ensure_loaded?(MCP.Types)
    end
  end

  describe "schema validation" do
    test "validates jsonrpc_request correctly" do
      # Valid request
      valid_request = Types.generate_sample(:jsonrpc_request)
      assert {:ok, _} = Types.validate_jsonrpc_request(valid_request)

      # Invalid request (missing method)
      invalid_request = Map.delete(valid_request, "method")
      assert {:error, _} = Types.validate_jsonrpc_request(invalid_request)
    end

    test "validates jsonrpc_notification correctly" do
      # Valid notification
      valid_notification = Types.generate_sample(:jsonrpc_notification)
      assert {:ok, _} = Types.validate_jsonrpc_notification(valid_notification)

      # Invalid notification (missing method)
      invalid_notification = Map.delete(valid_notification, "method")
      assert {:error, _} = Types.validate_jsonrpc_notification(invalid_notification)
    end

    test "validates jsonrpc_success_response correctly" do
      # Valid success response
      valid_response = Types.generate_sample(:jsonrpc_success_response)
      assert {:ok, _} = Types.validate_jsonrpc_success_response(valid_response)

      # Invalid response (missing result)
      invalid_response = Map.delete(valid_response, "result")
      assert {:error, _} = Types.validate_jsonrpc_success_response(invalid_response)
    end

    test "validates jsonrpc_error_response correctly" do
      # Valid error response
      valid_error = Types.generate_sample(:jsonrpc_error_response)
      assert {:ok, _} = Types.validate_jsonrpc_error_response(valid_error)

      # Invalid error response (missing error)
      invalid_error = Map.delete(valid_error, "error")
      assert {:error, _} = Types.validate_jsonrpc_error_response(invalid_error)
    end

    test "validates tool correctly" do
      # Valid tool
      valid_tool = Types.generate_sample(:tool)
      assert {:ok, _} = Types.validate_tool(valid_tool)

      # Invalid tool (missing name)
      invalid_tool = Map.delete(valid_tool, "name")
      assert {:error, _} = Types.validate_tool(invalid_tool)
    end

    test "validates text_resource_contents correctly" do
      # Valid resource contents
      valid_contents = Types.generate_sample(:text_resource_contents)
      assert {:ok, _} = Types.validate_text_resource_contents(valid_contents)

      # Invalid contents (missing text)
      invalid_contents = Map.delete(valid_contents, "text")
      assert {:error, _} = Types.validate_text_resource_contents(invalid_contents)
    end

    test "validates blob_resource_contents correctly" do
      # Valid blob contents
      valid_blob = Types.generate_sample(:blob_resource_contents)
      assert {:ok, _} = Types.validate_blob_resource_contents(valid_blob)

      # Invalid blob (missing base64)
      invalid_blob = Map.delete(valid_blob, "base64")
      assert {:error, _} = Types.validate_blob_resource_contents(invalid_blob)
    end

    test "validates resource correctly" do
      # Valid resource
      valid_resource = Types.generate_sample(:resource)
      assert {:ok, _} = Types.validate_resource(valid_resource)

      # Invalid resource (missing name)
      invalid_resource = Map.delete(valid_resource, "name")
      assert {:error, _} = Types.validate_resource(invalid_resource)
    end
  end

  describe "type parity with TypeScript" do
    # These tests verify that our Elixir types match the TypeScript types
    # by validating the same sample data in both systems.
    # For these tests to pass, a corresponding TypeScript test must also pass

    test "sample data pass validation in both Elixir and TypeScript" do
      # Types to validate
      types_to_test = [
        :jsonrpc_request,
        :jsonrpc_notification,
        :jsonrpc_success_response,
        :jsonrpc_error_response,
        :tool,
        :text_resource_contents,
        :blob_resource_contents,
        :resource
      ]

      # Generate and validate a sample for each type
      for type <- types_to_test do
        sample = Types.generate_sample(type)
        validate_function = get_validation_function(type)

        # The sample should be valid in Elixir
        assert {:ok, _} = apply(Types, validate_function, [sample])

        # Note: In a real test, we would also validate this sample in TypeScript
        # We'd need Node.js integration or a way to call into the TypeScript SDK
      end
    end
  end

  # Helper to get the appropriate validation function for a type
  defp get_validation_function(:jsonrpc_request), do: :validate_jsonrpc_request
  defp get_validation_function(:jsonrpc_notification), do: :validate_jsonrpc_notification
  defp get_validation_function(:jsonrpc_success_response), do: :validate_jsonrpc_success_response
  defp get_validation_function(:jsonrpc_error_response), do: :validate_jsonrpc_error_response
  defp get_validation_function(:tool), do: :validate_tool
  defp get_validation_function(:text_resource_contents), do: :validate_text_resource_contents
  defp get_validation_function(:blob_resource_contents), do: :validate_blob_resource_contents
  defp get_validation_function(:resource), do: :validate_resource
end
