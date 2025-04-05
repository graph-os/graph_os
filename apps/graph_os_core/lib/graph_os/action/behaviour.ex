defmodule GraphOS.Action.Behaviour do
  @moduledoc """
  Defines the `@action_meta` attribute for annotating action functions.

  Components implementing actions can `use` this module (or a similar one)
  to signal their intent and potentially leverage future compile-time
  registration features.

  Currently, this primarily serves to define the expected structure
  of the metadata. Registration still needs to be handled, potentially
  manually or via a more advanced macro in the component itself.
  """

  @doc """
  Module attribute to store metadata for an action function.

  Expected keys:
  - `:input_schema` (map, required): JSON Schema for arguments.
  - `:scope_extractor` (function/1, required): Extracts the resource scope ID from args.
  - `:description` (string, optional): Human-readable description.
  """
  Module.register_attribute(__MODULE__, :action_meta, accumulate: false, persist: true)

  # Potential future extension:
  # defmacro __using__(_opts) do
  #   quote do
  #     import GraphOS.Action.Behaviour, only: [action_meta: 1]
  #     Module.register_attribute(__MODULE__, :action_meta, accumulate: false, persist: true)
  #
  #     # Could add @before_compile or @on_definition hooks here later
  #     # for automatic registration with GraphOS.Action.Registry
  #   end
  # end
  #
  # defmacro action_meta(meta) do
  #   quote do
  #     @action_meta unquote(meta)
  #   end
  # end

end
