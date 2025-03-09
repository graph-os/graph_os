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

# Configure graph_os_dev application
config :graph_os_dev,
  namespace: GraphOS.Dev,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GraphOS.DevWeb.ErrorHTML, json: GraphOS.DevWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GraphOS.Dev.PubSub,
  live_view: [signing_salt: "zJUMk6G2"]

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
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure MCP HTTP server
config :graph_os_mcp,
  http_port: String.to_integer(System.get_env("MCP_HTTP_PORT", "4000")),
  http_host: {0, 0, 0, 0},
  http_base_path: "/mcp"

# Configure mime types for SSE
config :mime, :types, %{
  "text/event-stream" => ["sse"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
