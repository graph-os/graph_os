defmodule GraphOS.Core.FileSystem do
  @moduledoc """
  Represents the FileSystem graph entity.
  Acts as a container for File nodes and potentially defines graph-level actions.
  """
  use GraphOS.Entity.Graph # Assuming this exists and sets up entity behaviour

  # TODO: Implement graph query functions (get/3, get_by_path/3)
  # TODO: Define graph-level actions (e.g., watch_dir, index_dir) using handle_action/4
  # TODO: Define graph queries (e.g., get_path, get_file_node)
  # TODO: Define subscription capabilities
end
