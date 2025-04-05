import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :graph_os_web, GraphOS.WebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "CjN3v1SVBEcYT0Ub0xT+0wuykebya4WtumaoxnIwIh4wR/V8rAkeMm0hUx7p66p1",
  server: false

# In test we don't send emails
config :graph_os_web, GraphOS.Web.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "W7ohUVB1AoSFkFSS9SBuFFdUU2sfayhN2Nv1zAy0TNTSfg5aHS0DlOAcWMdglbMY",
  server: false

# Print debug messages during test to see detailed flow
config :logger, level: :debug

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure query module for the GraphController
config :graph_os_dev,
  query_module: GraphOS.Graph.Query

# Configure Bandit port for tests (used by graph_os_protocol and McpServerCase)
# Use a distinct port from the default dev port (4000)
config :bandit, port: 4001

# Configure protocol RPC secret for tests
# This is a fixed test value for predictable test outcomes
config :graph_os_protocol, :auth,
  rpc_secret: "test_only_secret_not_for_production",
  required: true

# Configure the MCP implementation module for tests
config :mcp, :implementation_module, GraphOS.Protocol.MCPImplementation
