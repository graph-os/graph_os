ExUnit.start()

# Ensure Mox is available
{:ok, _} = Application.ensure_all_started(:mox)

# Define mocks
Mox.defmock(GraphOS.Graph.MockQuery, for: GraphOS.Graph.QueryBehaviour)

# Set mock as default implementation in test environment
Application.put_env(:graph_os_mcp, :query_module, GraphOS.Graph.MockQuery)
