# Load support files for testing
Code.require_file("support/graph_factory.ex", __DIR__)

# Start the Registry for Store adapter tests
{:ok, _registry} = Registry.start_link(keys: :unique, name: GraphOS.Store.Registry)

# Define ExUnit.start options
run_incomplete = System.get_env("MIX_RUN_INCOMPLETE") == "true"
run_performance = System.get_env("MIX_RUN_PERFORMANCE") == "true"

# Determine which test types to exclude
exclude = []
exclude = if run_incomplete, do: exclude, else: [:incomplete_implementation | exclude]
exclude = if run_performance, do: exclude, else: [:performance | exclude]

# Create a setup handler to reset ETS tables before each test
ExUnit.configure(
  exclude: exclude,
  setup_all: fn _tags ->
    # Setup for each test module
    # {:ok, _} = GraphOS.Store.init()

    # We'll still reset before each individual test too
    GraphOS.Test.Support.GraphFactory.reset_store()
    :ok
  end,
  setup: fn _tags ->
    # Reset the ETS store before each individual test
    GraphOS.Test.Support.GraphFactory.reset_store()
    :ok
  end
)

ExUnit.start()

# Setup for all tests
# We removed the global Store.init() here as tests manage their own stores
# Each test module using the Store should implement its own setup
# using GraphOS.Store.start_link and on_exit.
# Ecto.Adapters.SQL.Sandbox.mode(GraphOS.Repo, :manual) # Removed: Ecto is not a dependency
