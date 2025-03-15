defmodule GraphOS.Component.Builder do
  @moduledoc """
  Provides DSL macros for defining tools and resources in components.
  
  This module contains the macros used to define executable tools and queryable
  resources within GraphOS components. It's typically used through the
  `use GraphOS.Component.Builder` call in a component module.
  """
  
  alias GraphOS.Component.Context
  
  @doc """
  Defines a new executable tool in the component.
  """
  defmacro tool(name, options) do
    description = Keyword.get(options, :description, "")
    params = Keyword.get(options, :params, [])
    execute_fn = Keyword.get(options, :execute)
    
    if is_nil(execute_fn) do
      raise ArgumentError, "tool requires an :execute function"
    end
    
    quote bind_quoted: [
      name: name,
      description: description, 
      params: params,
      execute_fn: Macro.escape(execute_fn)
    ] do
      # Store the tool info in module attribute
      tool_info = %{
        name: name,
        description: description,
        params: Map.new(params),
        execute_fn: execute_fn
      }
      
      # No need for erlang attachment
      
      Module.put_attribute(__MODULE__, :tools, {name, tool_info})
      
      # Define the tool execution function
      def execute_tool(unquote(name), context, params) do
        validate_params = fn params, _tool_info ->
          # For now, we just pass through the params without validation
          # This will be expanded in a future implementation
          {:ok, params}
        end
        
        case validate_params.(params, unquote(Macro.escape(tool_info))) do
          {:ok, valid_params} ->
            unquote(execute_fn).(context, valid_params)
          {:error, reason} ->
            Context.put_error(context, :invalid_params, reason)
        end
      end
    end
  end
  
  @doc """
  Defines a new queryable resource in the component.
  """
  defmacro resource(name, options) do
    description = Keyword.get(options, :description, "")
    params = Keyword.get(options, :params, [])
    query_fn = Keyword.get(options, :query)
    
    if is_nil(query_fn) do
      raise ArgumentError, "resource requires a :query function"
    end
    
    quote bind_quoted: [
      name: name,
      description: description, 
      params: params,
      query_fn: Macro.escape(query_fn)
    ] do
      # Store the resource info in module attribute
      resource_info = %{
        name: name,
        description: description,
        params: Map.new(params),
        query_fn: query_fn
      }
      
      # No need for erlang attachment
      
      Module.put_attribute(__MODULE__, :resources, {name, resource_info})
      
      # Define the resource query function
      def query_resource(unquote(name), context, params) do
        validate_params = fn params, _resource_info ->
          # For now, we just pass through the params without validation
          # This will be expanded in a future implementation
          {:ok, params}
        end
        
        case validate_params.(params, unquote(Macro.escape(resource_info))) do
          {:ok, valid_params} ->
            unquote(query_fn).(context, valid_params)
          {:error, reason} ->
            Context.put_error(context, :invalid_params, reason)
        end
      end
    end
  end
  
  @doc false
  defmacro __using__(_opts) do
    quote do
      import GraphOS.Component.Builder, only: [tool: 2, resource: 2]
      Module.register_attribute(__MODULE__, :tools, accumulate: true)
      Module.register_attribute(__MODULE__, :resources, accumulate: true)
      
      @before_compile {GraphOS.Component.Builder, :__before_compile__}
    end
  end
  
  @doc false
  defmacro __before_compile__(env) do
    tools = Module.get_attribute(env.module, :tools) || []
    resources = Module.get_attribute(env.module, :resources) || []
    
    tools_map = Enum.into(tools, %{})
    resources_map = Enum.into(resources, %{})
    
    quote do
      def __tools__ do
        unquote(Macro.escape(tools_map))
      end
      
      def __resources__ do
        unquote(Macro.escape(resources_map))
      end
      
      # Default implementations for execute_tool and query_resource
      def execute_tool(name, context, _params) do
        Context.put_error(context, :unknown_tool, "Unknown tool: #{inspect(name)}")
      end
      
      def query_resource(name, context, _params) do
        Context.put_error(context, :unknown_resource, "Unknown resource: #{inspect(name)}")
      end
      
      defoverridable execute_tool: 3, query_resource: 3
    end
  end
end