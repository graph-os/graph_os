defmodule MCP.Types do
  @moduledoc """
  Type definitions for MCP (Model Context Protocol) implementation.

  This module defines Elixir types that directly correspond to the TypeScript
  types exported by the MCP TypeScript SDK. It provides both:

  1. Elixir typespecs for static analysis and documentation
  2. JSON schema validation for runtime type checking

  Types are verified to have 1:1 parity with the TypeScript SDK via
  automated tests.
  """

  alias ExJsonSchema.Schema

  #
  # Constants
  #

  @latest_protocol_version "2024-11-05"
  @jsonrpc_version "2.0"

  def latest_protocol_version, do: @latest_protocol_version
  def jsonrpc_version, do: @jsonrpc_version

  #
  # Basic Types
  #

  @typedoc "Union of string or number for progress tokens"
  @type progress_token :: String.t() | number()

  @typedoc "Opaque cursor token for pagination"
  @type cursor :: String.t()

  @typedoc "Request ID can be string or number"
  @type request_id :: String.t() | number()

  #
  # Core Protocol Types
  #

  @typedoc "Basic request structure"
  @type request :: %{
    method: String.t(),
    params: map() | nil
  }

  @typedoc "Basic notification structure"
  @type notification :: %{
    method: String.t(),
    params: map() | nil
  }

  @typedoc "Basic result structure"
  @type result :: %{
    _meta: map() | nil
  }

  #
  # JSON-RPC Types
  #

  @typedoc "JSON-RPC Request"
  @type jsonrpc_request :: %{
    jsonrpc: String.t(),
    id: request_id(),
    method: String.t(),
    params: map() | nil
  }

  @typedoc "JSON-RPC Notification (no ID)"
  @type jsonrpc_notification :: %{
    jsonrpc: String.t(),
    method: String.t(),
    params: map() | nil
  }

  @typedoc "JSON-RPC Success Response"
  @type jsonrpc_success_response :: %{
    jsonrpc: String.t(),
    id: request_id(),
    result: map()
  }

  @typedoc "JSON-RPC Error Response"
  @type jsonrpc_error_response :: %{
    jsonrpc: String.t(),
    id: request_id() | nil,
    error: %{
      code: integer(),
      message: String.t(),
      data: any() | nil
    }
  }

  @typedoc "JSON-RPC Response (success or error)"
  @type jsonrpc_response :: jsonrpc_success_response() | jsonrpc_error_response()

  @typedoc "JSON-RPC Message (any type)"
  @type jsonrpc_message :: jsonrpc_request() | jsonrpc_notification() | jsonrpc_response()

  #
  # Tool Types
  #

  @typedoc "MCP Tool definition"
  @type tool :: %{
    name: String.t(),
    description: String.t() | nil,
    inputSchema: %{
      type: String.t(),  # Always "object"
      properties: map() | nil
    }
  }

  @typedoc "Call Tool Result"
  @type call_tool_result :: %{
    _meta: map() | nil,
    result: any()
  }

  #
  # Resource Types
  #

  @typedoc "Resource Contents"
  @type resource_contents :: text_resource_contents() | blob_resource_contents()

  @typedoc "Text Resource Contents"
  @type text_resource_contents :: %{
    uri: String.t(),
    mimeType: String.t(),
    text: String.t()
  }

  @typedoc "Blob Resource Contents"
  @type blob_resource_contents :: %{
    uri: String.t(),
    mimeType: String.t(),
    base64: String.t()
  }

  @typedoc "Resource definition"
  @type resource :: %{
    uri: String.t(),
    name: String.t(),
    description: String.t() | nil
  }

  #
  # Schema Definitions
  #

  @doc """
  Gets the JSON schema for a JSON-RPC request.
  """
  @spec get_jsonrpc_request_schema() :: map()
  def get_jsonrpc_request_schema do
    %{
      "type" => "object",
      "required" => ["jsonrpc", "method", "id"],
      "properties" => %{
        "jsonrpc" => %{
          "type" => "string",
          "enum" => [@jsonrpc_version]
        },
        "id" => %{
          "type" => ["string", "number"]
        },
        "method" => %{
          "type" => "string"
        },
        "params" => %{
          "type" => ["object", "null"]
        }
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a JSON-RPC notification.
  """
  @spec get_jsonrpc_notification_schema() :: map()
  def get_jsonrpc_notification_schema do
    %{
      "type" => "object",
      "required" => ["jsonrpc", "method"],
      "properties" => %{
        "jsonrpc" => %{
          "type" => "string",
          "enum" => [@jsonrpc_version]
        },
        "method" => %{
          "type" => "string"
        },
        "params" => %{
          "type" => ["object", "null"]
        }
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a JSON-RPC success response.
  """
  @spec get_jsonrpc_success_response_schema() :: map()
  def get_jsonrpc_success_response_schema do
    %{
      "type" => "object",
      "required" => ["jsonrpc", "id", "result"],
      "properties" => %{
        "jsonrpc" => %{
          "type" => "string",
          "enum" => [@jsonrpc_version]
        },
        "id" => %{
          "type" => ["string", "number"]
        },
        "result" => %{
          "type" => "object"
        }
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a JSON-RPC error response.
  """
  @spec get_jsonrpc_error_response_schema() :: map()
  def get_jsonrpc_error_response_schema do
    %{
      "type" => "object",
      "required" => ["jsonrpc", "error"],
      "properties" => %{
        "jsonrpc" => %{
          "type" => "string",
          "enum" => [@jsonrpc_version]
        },
        "id" => %{
          "type" => ["string", "number", "null"]
        },
        "error" => %{
          "type" => "object",
          "required" => ["code", "message"],
          "properties" => %{
            "code" => %{
              "type" => "integer"
            },
            "message" => %{
              "type" => "string"
            },
            "data" => %{
              "type" => ["object", "string", "number", "boolean", "array", "null"]
            }
          }
        }
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a tool definition.
  """
  @spec get_tool_schema() :: map()
  def get_tool_schema do
    %{
      "type" => "object",
      "required" => ["name", "inputSchema"],
      "properties" => %{
        "name" => %{
          "type" => "string"
        },
        "description" => %{
          "type" => ["string", "null"]
        },
        "inputSchema" => %{
          "type" => "object",
          "required" => ["type"],
          "properties" => %{
            "type" => %{
              "type" => "string",
              "enum" => ["object"]
            },
            "properties" => %{
              "type" => ["object", "null"]
            }
          }
        }
      }
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a text resource contents.
  """
  @spec get_text_resource_contents_schema() :: map()
  def get_text_resource_contents_schema do
    %{
      "type" => "object",
      "required" => ["uri", "mimeType", "text"],
      "properties" => %{
        "uri" => %{
          "type" => "string"
        },
        "mimeType" => %{
          "type" => "string"
        },
        "text" => %{
          "type" => "string"
        }
      }
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a blob resource contents.
  """
  @spec get_blob_resource_contents_schema() :: map()
  def get_blob_resource_contents_schema do
    %{
      "type" => "object",
      "required" => ["uri", "mimeType", "base64"],
      "properties" => %{
        "uri" => %{
          "type" => "string"
        },
        "mimeType" => %{
          "type" => "string"
        },
        "base64" => %{
          "type" => "string"
        }
      }
    }
    |> Schema.resolve()
  end

  @doc """
  Gets the JSON schema for a resource definition.
  """
  @spec get_resource_schema() :: map()
  def get_resource_schema do
    %{
      "type" => "object",
      "required" => ["uri", "name"],
      "properties" => %{
        "uri" => %{
          "type" => "string"
        },
        "name" => %{
          "type" => "string"
        },
        "description" => %{
          "type" => ["string", "null"]
        }
      }
    }
    |> Schema.resolve()
  end

  #
  # Validation Functions
  #

  @doc """
  Validates a JSON-RPC request.
  """
  @spec validate_jsonrpc_request(map()) :: {:ok, map()} | {:error, list()}
  def validate_jsonrpc_request(data) do
    validate_against_schema(data, get_jsonrpc_request_schema())
  end

  @doc """
  Validates a JSON-RPC notification.
  """
  @spec validate_jsonrpc_notification(map()) :: {:ok, map()} | {:error, list()}
  def validate_jsonrpc_notification(data) do
    validate_against_schema(data, get_jsonrpc_notification_schema())
  end

  @doc """
  Validates a JSON-RPC success response.
  """
  @spec validate_jsonrpc_success_response(map()) :: {:ok, map()} | {:error, list()}
  def validate_jsonrpc_success_response(data) do
    validate_against_schema(data, get_jsonrpc_success_response_schema())
  end

  @doc """
  Validates a JSON-RPC error response.
  """
  @spec validate_jsonrpc_error_response(map()) :: {:ok, map()} | {:error, list()}
  def validate_jsonrpc_error_response(data) do
    validate_against_schema(data, get_jsonrpc_error_response_schema())
  end

  @doc """
  Validates a tool definition.
  """
  @spec validate_tool(map()) :: {:ok, map()} | {:error, list()}
  def validate_tool(data) do
    validate_against_schema(data, get_tool_schema())
  end

  @doc """
  Validates a text resource contents.
  """
  @spec validate_text_resource_contents(map()) :: {:ok, map()} | {:error, list()}
  def validate_text_resource_contents(data) do
    validate_against_schema(data, get_text_resource_contents_schema())
  end

  @doc """
  Validates a blob resource contents.
  """
  @spec validate_blob_resource_contents(map()) :: {:ok, map()} | {:error, list()}
  def validate_blob_resource_contents(data) do
    validate_against_schema(data, get_blob_resource_contents_schema())
  end

  @doc """
  Validates a resource definition.
  """
  @spec validate_resource(map()) :: {:ok, map()} | {:error, list()}
  def validate_resource(data) do
    validate_against_schema(data, get_resource_schema())
  end

  @doc """
  Generic function to validate data against a JSON schema.
  """
  @spec validate_against_schema(map(), map()) :: {:ok, map()} | {:error, list()}
  def validate_against_schema(data, schema) do
    case ExJsonSchema.Validator.validate(schema, data) do
      :ok -> {:ok, data}
      {:error, errors} -> {:error, errors}
    end
  end

  @doc """
  Parse and validate JSON-RPC message.
  """
  @spec parse_jsonrpc_message(binary()) ::
    {:ok, map()} |
    {:error, :invalid_json | list()}
  def parse_jsonrpc_message(json) do
    with {:ok, decoded} <- Jason.decode(json),
         {:ok, _} <- determine_and_validate_message_type(decoded) do
      {:ok, decoded}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      error -> error
    end
  end

  @doc """
  Determines the type of JSON-RPC message and validates it accordingly.
  """
  @spec determine_and_validate_message_type(map()) ::
    {:ok, :request | :notification | :success_response | :error_response} |
    {:error, list()}
  def determine_and_validate_message_type(message) do
    cond do
      request_message?(message) -> validate_as_request(message)
      notification_message?(message) -> validate_as_notification(message)
      success_response_message?(message) -> validate_as_success_response(message)
      error_response_message?(message) -> validate_as_error_response(message)
      true -> {:error, ["Not a valid JSON-RPC message"]}
    end
  end

  # Helper predicates for message type detection
  defp request_message?(message), do: Map.has_key?(message, "id") && Map.has_key?(message, "method")
  defp notification_message?(message), do: Map.has_key?(message, "method") && !Map.has_key?(message, "id")
  defp success_response_message?(message), do: Map.has_key?(message, "id") && Map.has_key?(message, "result")
  defp error_response_message?(message), do: Map.has_key?(message, "error")

  # Helper functions for validation by message type
  defp validate_as_request(message) do
    case validate_jsonrpc_request(message) do
      {:ok, _} -> {:ok, :request}
      error -> error
    end
  end

  defp validate_as_notification(message) do
    case validate_jsonrpc_notification(message) do
      {:ok, _} -> {:ok, :notification}
      error -> error
    end
  end

  defp validate_as_success_response(message) do
    case validate_jsonrpc_success_response(message) do
      {:ok, _} -> {:ok, :success_response}
      error -> error
    end
  end

  defp validate_as_error_response(message) do
    case validate_jsonrpc_error_response(message) do
      {:ok, _} -> {:ok, :error_response}
      error -> error
    end
  end

  #
  # Type Parity Testing
  #

  @doc """
  Generates sample data for a given type.

  This function is used in tests to verify type parity with TypeScript.
  """
  @spec generate_sample(atom()) :: map() | term()
  def generate_sample(:jsonrpc_request) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => "req-123",
      "method" => "test.method",
      "params" => %{"foo" => "bar"}
    }
  end

  def generate_sample(:jsonrpc_notification) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => "test.notification",
      "params" => %{"event" => "something_happened"}
    }
  end

  def generate_sample(:jsonrpc_success_response) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => "req-123",
      "result" => %{"value" => 42}
    }
  end

  def generate_sample(:jsonrpc_error_response) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => "req-123",
      "error" => %{
        "code" => -32_000,
        "message" => "Error message",
        "data" => %{"details" => "Additional information"}
      }
    }
  end

  def generate_sample(:tool) do
    %{
      "name" => "test_tool",
      "description" => "A test tool",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "input" => %{"type" => "string"}
        }
      }
    }
  end

  def generate_sample(:text_resource_contents) do
    %{
      "uri" => "resource:test",
      "mimeType" => "text/plain",
      "text" => "Sample text content"
    }
  end

  def generate_sample(:blob_resource_contents) do
    %{
      "uri" => "resource:test-blob",
      "mimeType" => "application/octet-stream",
      "base64" => "SGVsbG8gV29ybGQ="  # "Hello World"
    }
  end

  def generate_sample(:resource) do
    %{
      "uri" => "resource:test",
      "name" => "Test Resource",
      "description" => "A test resource"
    }
  end

  # Add more sample generators as needed
end
