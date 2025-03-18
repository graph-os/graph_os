ExUnit.start()

# Mock the GraphOS.Graph.Schema.Protobuf module for testing
defmodule GraphOS.Graph.Schema.Protobuf do
  @moduledoc false

  def get_proto_definition(_schema_module, _msg_type) do
    # Return a simple mock definition
    %{fields: []}
  end

  def proto_to_map(request, _proto_def) do
    request |> Map.from_struct() |> Enum.reject(fn {_k, v} -> v == nil end) |> Enum.into(%{})
  end

  def map_to_proto(result, _proto_def, response_type) do
    struct(response_type, result)
  end

  def encode(proto_struct) do
    GraphOS.Protocol.Test.MockProto.encode(proto_struct)
  end

  def decode(binary, msg_type) do
    GraphOS.Protocol.Test.MockProto.decode(binary, msg_type)
  end
end

# Mock GraphOS.Adapter.GenServer module for testing
defmodule GraphOS.Adapter.GenServer do
  @moduledoc false

  def call(pid, msg) do
    GenServer.call(pid, msg)
  end

  def stop(pid, reason) do
    GenServer.stop(pid, reason)
  end

  def execute(adapter, operation, context) do
    GenServer.call(adapter, {:execute, operation, context})
  end

  def start_link(opts) do
    {:ok, self()}
  end
end

# Ensure test/support directory exists
File.mkdir_p!("test/support")

# Compile support modules explicitly by including the directory in elixirc_paths
# (This is done in mix.exs but we ensure test files are loaded here)
Application.ensure_all_started(:meck)
