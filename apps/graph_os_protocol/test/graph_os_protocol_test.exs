defmodule GraphOS.ProtocolTest do
  use ExUnit.Case

  test "the protocol schema module exists" do
    assert Code.ensure_loaded?(GraphOS.Protocol.Schema)
  end

  test "the GRPC adapter module exists" do
    assert Code.ensure_loaded?(GraphOS.Protocol.GRPC)
  end

  test "the JSONRPC adapter module exists" do
    assert Code.ensure_loaded?(GraphOS.Protocol.JSONRPC)
  end

  test "the Plug adapter module exists" do
    assert Code.ensure_loaded?(GraphOS.Protocol.Plug)
  end

  test "the protocol Schema upgrade functions are defined" do
    # Test that the upgrade functions exist
    assert function_exported?(GraphOS.Protocol.Schema, :upgrade_to_jsonrpc, 3)
    assert function_exported?(GraphOS.Protocol.Schema, :upgrade_to_plug, 3)
    assert function_exported?(GraphOS.Protocol.Schema, :upgrade_to_mcp, 3)
  end
end
