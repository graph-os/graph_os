defmodule GraphOS.Component.Registry do
  @moduledoc """
  Registry for GraphOS components, tools, and resources.
  
  This module provides a centralized registry for all components, tools, and
  resources in the GraphOS system. It allows for discovery and lookup of
  components and their capabilities.
  
  The registry is built at application startup and can be updated dynamically
  as new components are registered.
  """
  
  use GenServer
  require Logger

  @registry_table :graphos_component_registry

  # Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Registers a component module in the registry.
  
  This function analyzes the component module, extracting information about
  its tools and resources, and adds it to the registry.
  
  ## Parameters
  
    * `component` - The component module to register
    
  ## Returns
  
    * `:ok` if the component was registered successfully
    * `{:error, reason}` if registration failed
  """
  def register(component) when is_atom(component) do
    GenServer.call(__MODULE__, {:register, component})
  end

  @doc """
  Registers multiple component modules in the registry.
  
  ## Parameters
  
    * `components` - A list of component modules to register
    
  ## Returns
  
    * `:ok` if all components were registered successfully
    * `{:error, reason}` if registration failed
  """
  def register_many(components) when is_list(components) do
    GenServer.call(__MODULE__, {:register_many, components})
  end

  @doc """
  Looks up a component in the registry.
  
  ## Parameters
  
    * `component` - The component module to look up
    
  ## Returns
  
    * `{:ok, info}` if the component was found
    * `{:error, :not_found}` if the component was not found
  """
  def lookup_component(component) when is_atom(component) do
    case :ets.lookup(@registry_table, {:component, component}) do
      [{_, info}] -> {:ok, info}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a tool in the registry.
  
  ## Parameters
  
    * `tool_name` - The name of the tool to look up
    
  ## Returns
  
    * `{:ok, {component, tool_info}}` if the tool was found
    * `{:error, :not_found}` if the tool was not found
  """
  def lookup_tool(tool_name) when is_atom(tool_name) do
    case :ets.lookup(@registry_table, {:tool, tool_name}) do
      [{_, {component, tool_info}}] -> {:ok, {component, tool_info}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a resource in the registry.
  
  ## Parameters
  
    * `resource_name` - The name of the resource to look up
    
  ## Returns
  
    * `{:ok, {component, resource_info}}` if the resource was found
    * `{:error, :not_found}` if the resource was not found
  """
  def lookup_resource(resource_name) when is_atom(resource_name) do
    case :ets.lookup(@registry_table, {:resource, resource_name}) do
      [{_, {component, resource_info}}] -> {:ok, {component, resource_info}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered components.
  
  ## Returns
  
    * A list of `{component_module, info}` tuples
  """
  def list_components do
    :ets.match_object(@registry_table, {{:component, :_}, :_})
    |> Enum.map(fn {{:component, component}, info} -> {component, info} end)
  end

  @doc """
  Lists all registered tools.
  
  ## Returns
  
    * A list of `{tool_name, {component_module, tool_info}}` tuples
  """
  def list_tools do
    :ets.match_object(@registry_table, {{:tool, :_}, :_})
    |> Enum.map(fn {{:tool, tool}, info} -> {tool, info} end)
  end

  @doc """
  Lists all registered resources.
  
  ## Returns
  
    * A list of `{resource_name, {component_module, resource_info}}` tuples
  """
  def list_resources do
    :ets.match_object(@registry_table, {{:resource, :_}, :_})
    |> Enum.map(fn {{:resource, resource}, info} -> {resource, info} end)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@registry_table, [
      :set, 
      :named_table, 
      :public, 
      read_concurrency: true
    ])
    
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, component}, _from, state) do
    result = register_component(component)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:register_many, components}, _from, state) do
    results = Enum.map(components, &register_component/1)
    
    if Enum.all?(results, &(&1 == :ok)) do
      {:reply, :ok, state}
    else
      errors = Enum.filter(results, &(&1 != :ok))
      {:reply, {:error, errors}, state}
    end
  end

  # Private functions

  defp register_component(component) do
    try do
      # Ensure the module exists and is compiled
      Code.ensure_loaded!(component)
      
      # Check if the module is a component
      unless function_exported?(component, :call, 2) do
        raise "Module #{inspect(component)} is not a GraphOS.Component"
      end
      
      # Register the component
      component_info = %{
        module: component,
        tools: get_tools(component),
        resources: get_resources(component)
      }
      
      :ets.insert(@registry_table, {{:component, component}, component_info})
      
      # Register each tool
      if function_exported?(component, :__tools__, 0) do
        component.__tools__()
        |> Enum.each(fn {tool_name, tool_info} ->
          :ets.insert(@registry_table, {{:tool, tool_name}, {component, tool_info}})
        end)
      end
      
      # Register each resource
      if function_exported?(component, :__resources__, 0) do
        component.__resources__()
        |> Enum.each(fn {resource_name, resource_info} ->
          :ets.insert(@registry_table, {{:resource, resource_name}, {component, resource_info}})
        end)
      end
      
      :ok
    rescue
      e ->
        Logger.error("Failed to register component #{inspect(component)}: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  defp get_tools(component) do
    if function_exported?(component, :__tools__, 0) do
      component.__tools__()
    else
      %{}
    end
  end

  defp get_resources(component) do
    if function_exported?(component, :__resources__, 0) do
      component.__resources__()
    else
      %{}
    end
  end
end