defmodule GraphOS.ExecutableIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :code_graph

  alias GraphOS.Store

  @tag :integration
  @tag :skip
  test "integration tests are skipped for now" do
    # These integration tests require a more complete implementation
    # and will be enabled once the core functionality is stable
    assert true
  end
end
