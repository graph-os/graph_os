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

# Use different ports for MCP tests
config :graph_os_mcp,
  http_port: String.to_integer(System.get_env("MCP_HTTP_PORT", "4001")),
  http_host: {127, 0, 0, 1},
  # Disable the HTTP server during tests by default
  http_enabled: false
