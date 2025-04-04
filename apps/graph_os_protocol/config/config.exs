import Config

# Configure gRPC server
config :graph_os_protocol, :grpc,
  enabled: true,
  port: 50051,
  verbose: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# import_config "#{config_env()}.exs"
# Note: Uncomment the above line if you create dev/prod/test.exs files in this directory.
