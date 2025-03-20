fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create a temporary proto file from the schema definition in the Elixir code
    let proto_dir = std::path::PathBuf::from("src/proto");
    std::fs::create_dir_all(&proto_dir)?;
    
    let system_info_proto = r#"syntax = "proto3";

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
"#;

    let proto_file = proto_dir.join("system_info.proto");
    std::fs::write(&proto_file, system_info_proto)?;

    // Compile the proto file
    tonic_build::configure()
        .build_server(false)
        .build_client(true)
        .compile(&["src/proto/system_info.proto"], &["src/proto"])?;

    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/proto/system_info.proto");

    Ok(())
}