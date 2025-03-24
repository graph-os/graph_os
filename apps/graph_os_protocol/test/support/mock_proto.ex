defmodule GraphOS.Protocol.Test.MockProto do
  @moduledoc """
  Mock Protocol Buffer message types for testing.
  """

  defmodule SystemInfo do
    @moduledoc false
    use Protobuf,
      schema: """
        message SystemInfo {
          string id = 1;
          string hostname = 2;
          int64 timestamp = 3;
          int32 cpu_count = 4;
          double cpu_load_1m = 5;
          double cpu_load_5m = 6;
          double cpu_load_15m = 7;
          int64 memory_total = 8;
          int64 memory_used = 9;
          int64 memory_free = 10;
          int64 uptime = 11;
          string os_version = 12;
          string platform = 13;
          string architecture = 14;
        }
      """
  end

  defmodule SystemInfoList do
    @moduledoc false
    use Protobuf,
      schema: """
        message SystemInfoList {
          repeated SystemInfo items = 1;
        }
      """
  end

  defmodule GetSystemInfoRequest do
    @moduledoc false
    use Protobuf,
      schema: """
        message GetSystemInfoRequest {}
      """
  end

  defmodule ListSystemInfoRequest do
    @moduledoc false
    use Protobuf,
      schema: """
        message ListSystemInfoRequest {
          int32 limit = 1;
          int64 since = 2;
        }
      """
  end
end
