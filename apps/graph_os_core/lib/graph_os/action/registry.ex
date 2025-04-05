defmodule GraphOS.Action.Registry do
  @moduledoc """
  Manages the registration and lookup of GraphOS actions defined in components.

  Stores metadata associated with each action, such as input schema,
  description, and scope extractor function.

  This registry is typically populated at compile time by components
  using a behaviour or macro that scans for `@action_meta`.
  """
  use Agent

  # The state is a map: %{{module, function_atom} => %{meta_data}}
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Registers an action with its metadata.

  Called during compilation or application start.
  """
  def register(component_module, action_name, meta) when is_atom(component_module) and is_atom(action_name) and is_map(meta) do
    # Basic validation - could be expanded
    unless Map.has_key?(meta, :input_schema) and Map.has_key?(meta, :scope_extractor) do
      raise ArgumentError, "Action metadata for #{component_module}.#{action_name} must include :input_schema and :scope_extractor"
    end

    unless is_function(meta.scope_extractor, 1) do
       raise ArgumentError, ":scope_extractor for #{component_module}.#{action_name} must be a function of arity 1"
    end

    # TODO: Add JSON Schema validation for :input_schema if needed

    key = {component_module, action_name}
    Agent.update(__MODULE__, &Map.put(&1, key, meta))
    {:ok, key}
  end

  @doc """
  Retrieves the metadata for a specific action.
  """
  def get_meta({component_module, action_name} = key) when is_atom(component_module) and is_atom(action_name) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Lists all registered actions, optionally filtered by component module.

  Returns a list of tuples: `{{module, action_name}, metadata}`
  """
  def list_actions(component_module \\ nil) do
    actions = Agent.get(__MODULE__, & &1)

    if component_module do
      actions
      |> Enum.filter(fn {{mod, _action}, _meta} -> mod == component_module end)
    else
      actions |> Enum.to_list()
    end
  end

  @doc """
  Clears the registry. Useful for testing.
  """
  def clear do
    Agent.update(__MODULE__, fn _ -> %{} end)
  end
end
