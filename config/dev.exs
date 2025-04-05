import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
# Binding to loopback ipv4 address prevents access from other machines.
config :graph_os_web, GraphOS.WebWeb.Endpoint,
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "7pNMJoOYVuC+JD89ft1i6n2nhOonZZ4Z1qbOIjnsxf1ocDT4aBYjjnJ4PIGP3ahC",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:graph_os_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:graph_os_web, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :graph_os_web, GraphOS.WebWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/graph_os_web_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :graph_os_web, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure the MCP implementation module for dev environment
config :mcp, :implementation_module, GraphOS.Protocol.MCPImplementation

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# CodeGraph service is disabled during refactoring
config :graph_os_core,
  enable_code_graph: false,
  watch_directories: [
    "apps/graph_os_core/lib",
    "apps/graph_os_dev/lib",
    "apps/graph_os_store/lib"
  ],
  file_pattern: "**/*.ex",
  exclude_pattern: nil,
  auto_reload: false,
  poll_interval: 1000,
  distributed: false

# Configure query module for the GraphController
config :graph_os_dev,
  query_module: GraphOS.Graph.Query

# Configure protocol RPC secret and ports for development
# In production, this should be set via env vars in runtime.exs
config :graph_os_protocol, :auth,
  rpc_secret: "dev_only_8c5f243ed96a55ea767e41e75e2c38f09b07cec8",
  required: true

# Configure protocol server ports
config :graph_os_protocol, :grpc, port: 50051

config :graph_os_protocol, :jsonrpc, port: 4001
