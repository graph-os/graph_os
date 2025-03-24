defmodule GraphOS.Core do
  @moduledoc """
  GraphOS.Core provides the central functionality of the GraphOS system.

  This module serves as the main entry point to the GraphOS Core functionality,
  which includes:

  - Component system for building extensible pipelines
  - Code graph analysis and representation
  - Access control and permissions
  - Git integration
  - Executable graph nodes
  - Adapter system for various communication protocols

  ## Architecture

  GraphOS.Core depends on GraphOS.Store for its underlying graph data structures
  and operations, while providing higher-level functionality on top of that
  foundation.

  The module organization follows these principles:

  - `GraphOS.Core.*` - Core functionality modules
  - `GraphOS.Component.*` - Component system
  """

  @doc """
  Get the GraphOS version information.

  ## Examples

      iex> version_info = GraphOS.Core.version()
      iex> version_info.version
      "0.1.0"
  """
  def version do
    %{
      version: "0.1.0",
      env: Mix.env()
    }
  end
end
