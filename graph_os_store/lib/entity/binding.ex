defmodule GraphOS.Entity.Binding do
  @moduledoc """
  Configures the allowed source and target modules for an edge.
  """
  @type t :: %__MODULE__ {
    include: list(module()),
    exclude: list(module()),
  }

  defstruct [
    include: [],
    exclude: [],
  ]

  @doc """
  Creates a new edge binding.

  ## Options

  - `include`: A module or list of modules to include.
  - `exclude`: A module or list of modules to exclude.

  ## Examples

  iex> GraphOS.Entity.Binding.new(include: [MyApp.User], exclude: MyApp.Admin)
  %GraphOS.Entity.Binding{
    include: [MyApp.User],
    exclude: [MyApp.Admin]
  }

  iex> GraphOS.Entity.Binding.new(%{include: [MyApp.User], exclude: MyApp.Admin})
  %GraphOS.Entity.Binding{
    include: [MyApp.User],
    exclude: [MyApp.Admin]
  }
  """
  def new(opts) when is_list(opts) do
    include_value = Keyword.get(opts, :include, [])
    exclude_value = Keyword.get(opts, :exclude, [])

    %__MODULE__{
      include: normalize_modules(include_value),
      exclude: normalize_modules(exclude_value),
    }
  end

  def new(opts) when is_map(opts) do
    include_value = Map.get(opts, :include, [])
    exclude_value = Map.get(opts, :exclude, [])

    %__MODULE__{
      include: normalize_modules(include_value),
      exclude: normalize_modules(exclude_value),
    }
  end

  @doc """
  Normalizes a module or list of modules into a list.
  """
  @spec normalize_modules(module() | list(module())) :: list(module())
  def normalize_modules(modules) when is_list(modules), do: modules
  def normalize_modules(module) when is_atom(module) and not is_nil(module), do: [module]
  def normalize_modules(nil), do: []

  @doc """
  Validates an edge binding configuration.
  """
  @spec validate!(t()) :: t()
  def validate!(binding) do
    # Ensure all include modules are valid module names.
    for module <- binding.include do
      unless is_atom(module) and String.contains?(Atom.to_string(module), ".") do
        raise ArgumentError, "Invalid module: #{inspect(module)}"
      end
    end

    # Ensure all exclude modules are valid module names.
    for module <- binding.exclude do
      unless is_atom(module) and String.contains?(Atom.to_string(module), ".") do
        raise ArgumentError, "Invalid module: #{inspect(module)}"
      end
    end

    binding
  end

  @doc """
  Checks if a module is included in the binding.
  """
  @spec included?(t(), module()) :: boolean()
  def included?(%__MODULE__{} = binding, module) do
    # If no includes are specified, all modules are considered included
    binding.include == [] or
    Enum.any?(binding.include, fn included_module ->
      module == included_module
    end)
  end

  @doc """
  Checks if a module is excluded from the binding.
  """
  @spec excluded?(t(), module()) :: boolean()
  def excluded?(%__MODULE__{} = binding, module) do
    Enum.any?(binding.exclude, fn excluded_module ->
      module == excluded_module
    end)
  end

  @doc """
  Checks if a module is allowed by the binding.

  ## Logic

  - If `include` is defined (non-empty), only modules in the `include` list are allowed
  - If `exclude` is defined, any module not in the `exclude` list is allowed
  - If both are defined, a module must be in `include` AND not in `exclude` to be allowed
  - If neither is defined, all modules are allowed
  """
  @spec allowed?(t() | module(), module()) :: boolean()
  def allowed?(%__MODULE__{} = binding, module) do
    cond do
      # If both include and exclude are specified
      binding.include != [] and binding.exclude != [] ->
        included?(binding, module) and not excluded?(binding, module)

      # If only include is specified - only allow modules in the include list
      binding.include != [] ->
        included?(binding, module)

      # If only exclude is specified - allow all modules except those in the exclude list
      binding.exclude != [] ->
        not excluded?(binding, module)

      # If neither include nor exclude are specified - allow all modules
      true ->
        true
    end
  end

  def allowed?(entity_module, module) do
    if function_exported?(entity_module, :entity, 0) do
      entity = entity_module.entity()

      # An entity module should have a source and target binding
      # If it's an edge, we need to check if the module is allowed in either binding
      cond do
        Map.has_key?(entity, :source) and Map.has_key?(entity, :target) ->
          allowed?(entity.source, module) or allowed?(entity.target, module)
        Map.has_key?(entity, :binding) ->
          allowed?(entity.binding, module)
        true ->
          raise ArgumentError, "Entity #{inspect(entity_module)} does not have appropriate bindings"
      end
    else
      raise ArgumentError, "Module #{inspect(entity_module)} does not have an entity function"
    end
  end
end
