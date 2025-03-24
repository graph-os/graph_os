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

# GraphOS query module configuration
config :graph_os_dev,
  query_module: GraphOS.Store.Query,
  enable_code_graph: false
