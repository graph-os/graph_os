# GraphOS.GraphContext.Action

This document describes the GraphOS.GraphContext.Action system, a standardized approach for defining component actions in GraphOS.

## Overview

GraphOS.GraphContext.Action provides a consistent pattern for defining reusable, declarative graph operations. Actions encapsulate business logic that operates on the graph, with standardized parameter handling, validation, and execution patterns.

The Action system combines the strengths of Elixir's Plug pattern with GraphOS's graph-centric architecture, creating a familiar yet powerful interface for component developers.

## Principles

1. **Declarative Transactions**: Actions define graph operations declaratively
2. **Protocol Independence**: Actions are protocol-agnostic, usable with any adapter
3. **Standardized Interfaces**: Actions follow consistent patterns for parameters and returns
4. **Self-Documentation**: Actions document their input/output requirements
5. **Reusability**: Actions can be composed and shared across components

## Implementation

### GraphOS.GraphContext.Action Module

The core `GraphOS.GraphContext.Action` module provides a behavior and macros for defining actions:

```elixir
defmodule GraphOS.GraphContext.Action do
  @moduledoc """
  Defines a behavior for reusable, declarative graph actions.
  """
  
  @callback init(opts :: Keyword.t()) :: map()
  @callback call(conn :: map(), params :: map(), opts :: map()) :: 
    {:ok, result :: any()} | {:error, reason :: any()}
  
  defmacro __using__(_opts) do
    quote do
      import GraphOS.GraphContext.Action, only: [action: 1, action: 2]
      @behaviour GraphOS.GraphContext.Action
      @actions %{}
      @before_compile GraphOS.GraphContext.Action
      
      @impl true
      def init(opts), do: opts
    end
  end
  
  # Implementation details for compiling and registering actions
end
```

### Defining Actions

Component actions are defined in a dedicated module using the `action/1` or `action/2` macro:

```elixir
defmodule GraphOS.Components.SystemInfo.Actions do
  use GraphOS.GraphContext.Action
  
  # Define actions with metadata
  action :set_hostname, input: [:hostname], output: :system_info
  action :get_system_info
  
  @impl true
  def call(conn, params, %{action: :set_hostname}) do
    # Implementation for set_hostname action
    with {:ok, hostname} <- Map.fetch(params, "hostname") do
      # Define transaction declaratively
      transaction = %GraphOS.GraphContext.Transaction{
        operations: [
          %GraphOS.GraphContext.Operation{
            type: :action,
            path: "system.hostname.set",
            params: %{hostname: hostname}
          }
        ]
      }
      
      # Execute transaction
      GraphOS.GraphContext.execute(transaction)
    else
      :error -> {:error, {:missing_param, "hostname"}}
    end
  end
  
  def call(conn, _params, %{action: :get_system_info}) do
    # Query implementation
    GraphOS.GraphContext.query(%{
      path: "system.info",
      params: %{}
    })
  end
end
```

## Integration with Components

Actions are integrated into the component structure:

```
apps/graph_os_core/lib/graph_os/
  components/
    component_name/
      schema.proto          # Protocol Buffers schema
      schema.ex             # Schema module
      component.ex          # Main component implementation
      actions.ex            # Pre-defined actions
      controller.ex         # HTTP/RPC controller
      grpc.ex               # gRPC adapter
      jsonrpc.ex            # JSON-RPC adapter
      mcp.ex                # MCP adapter
    component_name.ex       # Public API
```

The main component module delegates to the Actions module:

```elixir
defmodule GraphOS.Components.SystemInfo do
  alias GraphOS.Components.SystemInfo.Actions
  
  # Delegate to Actions module
  defdelegate set_hostname(conn, params), to: Actions
  defdelegate get_system_info(conn, params), to: Actions
  
  # Registry information
  def __graphos_component__ do
    %{
      name: "system_info",
      schema_module: GraphOS.Components.SystemInfo.Schema,
      actions_module: GraphOS.Components.SystemInfo.Actions,
      actions: [:set_hostname, :get_system_info],
      queries: [:system_info]
    }
  end
end
```

## Protocol Adapters

Actions work seamlessly with different protocol adapters:

### HTTP Controllers

```elixir
defmodule GraphOS.Components.SystemInfo.Controller do
  use Phoenix.Controller
  
  alias GraphOS.Components.SystemInfo.Actions
  
  def set_hostname(conn, params) do
    case Actions.set_hostname(conn, params) do
      {:ok, system_info} ->
        conn |> put_status(200) |> json(system_info)
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end
end
```

### JSON-RPC Adapter

```elixir
defmodule GraphOS.Components.SystemInfo.JSONRPC do
  def handle_request("system.info.set_hostname", params, context) do
    GraphOS.Components.SystemInfo.Actions.set_hostname(context, params)
  end
end
```

### gRPC Adapter

```elixir
defmodule GraphOS.Components.SystemInfo.GRPC do
  def handle_SetHostname(request, context) do
    params = %{"hostname" => request.hostname}
    
    case GraphOS.Components.SystemInfo.Actions.set_hostname(context, params) do
      {:ok, result} -> 
        # Convert to protobuf response
        SystemInfoResponse.new(
          id: result.id,
          hostname: result.hostname,
          # other fields...
        )
      {:error, reason} ->
        # Handle error
    end
  end
end
```

## Component Registry Integration

The component registry discovers and manages actions:

```elixir
defmodule GraphOS.Components.Registry do
  # Get all actions for a component
  def component_actions(component_name) do
    with %{info: info} <- component(component_name),
         actions_module when not is_nil(actions_module) <- Map.get(info, :actions_module) do
      actions_module.__actions__()
    else
      _ -> %{}
    end
  end
  
  # Execute an action by name
  def execute_action(component_name, action_name, conn, params) do
    with %{info: info} <- component(component_name),
         actions_module when not is_nil(actions_module) <- Map.get(info, :actions_module) do
      apply(actions_module, action_name, [conn, params])
    else
      _ -> {:error, :action_not_found}
    end
  end
end
```

## Convention-based Routing

The Action system enables convention-based routing:

```elixir
defmodule GraphOS.Protocol.Router do
  def route_request(path, params, conn) do
    # Parse path like "component_name.action_name"
    [component_name, action_name] = String.split(path, ".", parts: 2)
    action_name = String.to_atom(action_name)
    
    GraphOS.Components.Registry.execute_action(
      component_name, 
      action_name, 
      conn, 
      params
    )
  end
end
```

## Benefits

1. **Minimal Token Usage**: Reduces the tokens needed to interact with GraphOS
2. **Consistent Pattern**: Provides a familiar interface for Elixir developers
3. **Protocol Agnostic**: Works with any communication protocol
4. **Self-Documented**: Actions document their input/output requirements
5. **Graph-Centric**: All state is maintained in the graph
6. **Composable**: Actions can be combined into complex workflows
7. **Discoverable**: Actions are registered and discoverable

## Examples

### Basic Action Usage

```elixir
# Direct usage
{:ok, system_info} = GraphOS.Components.SystemInfo.set_hostname(conn, %{"hostname" => "new-host"})

# Via Registry
{:ok, system_info} = GraphOS.Components.Registry.execute_action(
  "system_info", 
  :set_hostname, 
  conn, 
  %{"hostname" => "new-host"}
)
```

### JSON-RPC Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "graph.action.system_info.set_hostname",
  "params": {
    "hostname": "new-host"
  }
}
```

### GraphQL Interface (Future)

```graphql
mutation {
  systemInfo {
    setHostname(hostname: "new-host") {
      id
      hostname
      uptime
    }
  }
}
```

## Future Enhancements

1. **Action Pipelines**: Compose multiple actions into pipelines
2. **Middleware**: Add middleware for cross-cutting concerns
3. **Action Validation**: Automatic parameter validation based on schemas
4. **GraphQL Integration**: Generate GraphQL schema from actions
5. **Documentation Generation**: Auto-generate API documentation from actions