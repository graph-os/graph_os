import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "W7ohUVB1AoSFkFSS9SBuFFdUU2sfayhN2Nv1zAy0TNTSfg5aHS0DlOAcWMdglbMY",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure query module for the GraphController
config :graph_os_dev,
  query_module: GraphOS.Graph.Query
