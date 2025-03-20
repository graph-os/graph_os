defmodule GraphOS.Protocol.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Define the children to be supervised
    children = [
      # No default supervised children at this time
      # Protocol adapters are typically started by the applications that use them
    ]

    # Start the GRPC server if configured
    start_grpc_server()

    # Start the supervisor with the strategy
    opts = [strategy: :one_for_one, name: GraphOS.Protocol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Start the gRPC server if it's enabled in the configuration
  defp start_grpc_server do
    grpc_config = Application.get_env(:graph_os_protocol, :grpc, [])
    enabled = Keyword.get(grpc_config, :enabled, true)
    port = Keyword.get(grpc_config, :port, 50051)

    if enabled do
      Logger.info("Starting gRPC server on port #{port}")

      # Use the mock schema for testing
      # Make sure we use the correct module path - it's in the lib/protocol/test directory
      schema_module = GraphOS.Protocol.Test.MockSchema
      
      # Directly compile the schema for development rather than relying on code paths
      # This ensures the schema is always available
      try_compile_schema()

      # Start the gRPC adapter with the schema module
      case GraphOS.Protocol.GRPC.start_link(
        name: GraphOS.Protocol.GRPCServer,
        schema_module: schema_module,
        port: port,
        verbose: true
      ) do
        {:ok, _pid} ->
          Logger.info("gRPC server started successfully")
        
        {:error, reason} ->
          Logger.error("Failed to start gRPC server: #{inspect(reason)}")
      end
    else
      Logger.info("gRPC server disabled in configuration")
    end
  end
  
  # Compile the schema directly from the library path
  defp try_compile_schema do
    schema_path = Path.join([File.cwd!(), "apps", "graph_os_protocol", "lib", "protocol", "test", "mock_schema.ex"])
    
    if File.exists?(schema_path) do
      Logger.info("Found schema at #{schema_path}, compiling...")
      try do
        Code.compile_file(schema_path)
        Logger.info("Schema compiled successfully")
      rescue
        e -> 
          Logger.error("Failed to compile schema: #{inspect(e)}")
          # Create a minimal dynamic module as a last resort
          create_dynamic_schema_module()
      end
    else
      Logger.error("Could not find schema at #{schema_path}")
      create_dynamic_schema_module()
    end
  end
  
  # Create a minimal dynamic module as a last resort
  defp create_dynamic_schema_module do
    try do
      defmodule GraphOS.Protocol.Test.MockSchema do
        @moduledoc "Dynamically created schema module"
        @behaviour GraphOS.GraphContext.SchemaBehaviour
        def service_module, do: __MODULE__
        def proto_definition, do: ""
        def proto_field_mapping, do: %{}
        def fields, do: []
      end
      
      Logger.info("Created minimal dynamic schema module")
    rescue
      e -> Logger.error("Failed to create dynamic schema: #{inspect(e)}")
    end
  end
end
