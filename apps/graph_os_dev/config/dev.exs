import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "a0dyFv80aNOi7Vp2VLJwVn2ImgOGPrucQvZE66VTYlEiGVtfcr3Jef9ZHhGUbPPV",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:graph_os_dev, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:graph_os_dev, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/graph_os_dev_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :graph_os_dev, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Option 2: Phoenix-based MCP access (integrated UI experience)
# This configuration makes Phoenix forward MCP requests to the core MCP service.
# NOTE: Make sure auto_start_http in the root config/dev.exs is set correctly:
#   - If auto_start_http: true, this app will proxy to the standalone MCP server
#   - If auto_start_http: false, the MCP will not start its own HTTP server and
#     this app's MCPController will call the MCP endpoint directly
config :graph_os_mcp,
  http_port: 4000,  # Define but not used when auto_start_http is false
  http_host: {127, 0, 0, 1},
  http_base_path: "/mcp",  # Base path when accessed through Phoenix
  dev_mode: true  # Enable development features
