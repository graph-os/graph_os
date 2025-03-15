defmodule GraphOS.Component.Example do
  @moduledoc """
  An example component that demonstrates the Component API.
  
  This component provides:
  
  1. A simple tool that performs math operations
  2. A resource that returns mock user data
  3. Example of context transformation
  
  It serves as a reference implementation for building components.
  """
  
  use GraphOS.Component
  use GraphOS.Component.Builder
  
  alias GraphOS.Component.Context
  
  # Define the "math" tool
  tool :math,
    description: "Performs basic math operations",
    params: [
      operation: %{
        name: :operation,
        type: :string,
        required: true,
        description: "The operation to perform (add, subtract, multiply, divide)"
      },
      a: %{
        name: :a,
        type: :number,
        required: true,
        description: "First operand"
      },
      b: %{
        name: :b,
        type: :number,
        required: true,
        description: "Second operand"
      }
    ],
    execute: fn context, params ->
      result = case params.operation do
        "add" -> params.a + params.b
        "subtract" -> params.a - params.b
        "multiply" -> params.a * params.b
        "divide" when params.b != 0 -> params.a / params.b
        "divide" -> {:error, "Division by zero"}
        _ -> {:error, "Unknown operation: #{params.operation}"}
      end
      
      case result do
        {:error, message} -> Context.put_error(context, :invalid_operation, message)
        value -> Context.put_result(context, %{result: value})
      end
    end
  
  # Define the "echo" tool
  tool :echo,
    description: "Echoes back the input with optional transformation",
    params: [
      message: %{
        name: :message,
        type: :string,
        required: true,
        description: "Message to echo"
      },
      uppercase: %{
        name: :uppercase,
        type: :boolean,
        default: false,
        description: "Whether to convert to uppercase"
      }
    ],
    execute: fn context, params ->
      uppercase = Map.get(params, :uppercase, false)
      result = if uppercase, do: String.upcase(params.message), else: params.message
      Context.put_result(context, %{message: result})
    end
  
  # Define the "user" resource
  resource :user,
    description: "Retrieves user information",
    params: [
      id: %{
        name: :id,
        type: :string,
        required: true,
        description: "User ID"
      }
    ],
    query: fn context, params ->
      # Simulate database lookup
      user = case params.id do
        "1" -> %{id: "1", name: "Alice", email: "alice@example.com"}
        "2" -> %{id: "2", name: "Bob", email: "bob@example.com"}
        "3" -> %{id: "3", name: "Charlie", email: "charlie@example.com"}
        _ -> nil
      end
      
      if user do
        Context.put_result(context, user)
      else
        Context.put_error(context, :not_found, "User not found: #{params.id}")
      end
    end
  
  # Implement the Component behavior
  @impl true
  def init(opts) do
    default_prefix = "Example"
    %{prefix: Keyword.get(opts, :prefix, default_prefix)}
  end
  
  @impl true
  def call(context, opts) do
    # Add some metadata to the context
    context
    |> Context.put_metadata(:component, __MODULE__)
    |> Context.assign(:example_prefix, opts.prefix)
  end
end