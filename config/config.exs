# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config


# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  graph_os_dev: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/graph_os_dev/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  graph_os_dev: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/graph_os_dev/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id, :session_id, :params, :prompt_id, :resource_id, :tool_name, :arguments,
    :cursor, :limit, :protocol_version, :client_capabilities, :method, :errors, :error
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure mime types for SSE
config :mime, :types, %{
  "text/event-stream" => ["sse"],
  "application/grpc" => ["grpc"],
  "application/grpc+proto" => ["grpc_proto"]
}

# Configure gRPC server
config :graph_os_protocol, :grpc,
  enabled: true,
  port: 50051,
  verbose: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
