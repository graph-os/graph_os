defmodule GraphOS.Protocol.Test.MockSchema do
  @moduledoc """
  A mock schema implementation for testing the gRPC server.
  
  This is a minimal implementation to make the gRPC server start successfully.
  """
  @behaviour GraphOS.GraphContext.SchemaBehaviour

  # Service module for gRPC
  @impl true
  def service_module do
    __MODULE__
  end
  
  # Protobuf definition for the system info 
  @impl true
  def proto_definition do
    """
    syntax = "proto3";
    
    package graph_os;
    
    // SystemInfo represents basic system metrics and information
    message SystemInfo {
      string id = 1;                // Unique identifier
      string hostname = 2;          // Host system name
      int64 timestamp = 3;          // Collection timestamp (unix time)
      int32 cpu_count = 4;          // Number of CPU cores
      double cpu_load_1m = 5;       // 1-minute load average (Unix only)
      double cpu_load_5m = 6;       // 5-minute load average (Unix only)
      double cpu_load_15m = 7;      // 15-minute load average (Unix only)
      int64 memory_total = 8;       // Total memory in bytes (BEAM VM)
      int64 memory_used = 9;        // Used memory in bytes (BEAM VM)
      int64 memory_free = 10;       // Free memory in bytes (BEAM VM)
      int64 uptime = 11;            // System uptime in seconds
      string os_version = 12;       // OS version
      string platform = 13;         // Platform name
      string architecture = 14;     // System architecture
    }
    
    // SystemInfoList represents a collection of system info records
    message SystemInfoList {
      repeated SystemInfo items = 1; // List of system info items
    }
    
    // GetSystemInfoRequest gets current system info
    message GetSystemInfoRequest {}
    
    // ListSystemInfoRequest lists historical system info records
    message ListSystemInfoRequest {
      int32 limit = 1;              // Max number of records to return
      int64 since = 2;              // Get records since this timestamp
    }
    
    // SystemInfoService defines gRPC service for system information
    service SystemInfoService {
      // GetSystemInfo returns the current system information
      rpc GetSystemInfo(GetSystemInfoRequest) returns (SystemInfo);
      
      // ListSystemInfo returns historical system information
      rpc ListSystemInfo(ListSystemInfoRequest) returns (SystemInfoList);
    }
    """
  end
  
  # Field mapping
  @impl true
  def proto_field_mapping do
    %{
      "id" => :id,
      "hostname" => :hostname,
      "timestamp" => :timestamp,
      "cpu_count" => :cpu_count,
      "cpu_load_1m" => :cpu_load_1m,
      "cpu_load_5m" => :cpu_load_5m,
      "cpu_load_15m" => :cpu_load_15m,
      "memory_total" => :memory_total,
      "memory_used" => :memory_used,
      "memory_free" => :memory_free,
      "uptime" => :uptime,
      "os_version" => :os_version,
      "platform" => :platform,
      "architecture" => :architecture
    }
  end
  
  # Define fields
  @impl true
  def fields do
    [
      {:id, :string, [required: true]},
      {:hostname, :string, [required: true]},
      {:timestamp, :integer, [required: true]},
      {:cpu_count, :integer, [required: true]},
      {:cpu_load_1m, :float, [required: false]},
      {:cpu_load_5m, :float, [required: false]},
      {:cpu_load_15m, :float, [required: false]},
      {:memory_total, :integer, [required: true]},
      {:memory_used, :integer, [required: true]},
      {:memory_free, :integer, [required: true]},
      {:uptime, :integer, [required: true]},
      {:os_version, :string, [required: true]},
      {:platform, :string, [required: true]},
      {:architecture, :string, [required: true]}
    ]
  end
end