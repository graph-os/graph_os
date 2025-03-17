defmodule GraphOS.CoreTest do
  use ExUnit.Case
  doctest GraphOS.Core

  test "provides version info" do
    version_info = GraphOS.Core.version()
    assert is_map(version_info)
    assert version_info.version == "0.1.0"
    assert version_info.env == Mix.env()
  end
end
