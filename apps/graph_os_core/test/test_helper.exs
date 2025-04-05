# Only run tmux tests if MIX_USE_TMUX=true is set
# By default, we'll skip tmux tests
run_tmux_tests = System.get_env("MIX_USE_TMUX") == "true"

# Ensure dependent applications (like graph_os_store for Access/Store functions) are started
# Although store doesn't have an Application module, this ensures code is loaded.
Application.ensure_all_started(:graph_os_store)

# Explicitly start the Store Registry needed by GraphOS.Store.start_link/1
# This mimics the setup in graph_os_store's own test_helper.exs
{:ok, _store_registry} = Registry.start_link(keys: :unique, name: GraphOS.Store.Registry)

# Remove explicit start of main Registry; rely on OTP default if applicable
# {:ok, _main_registry} = Registry.start_link(keys: :unique, name: Registry)


# Exclude tmux tests unless explicitly enabled, and always exclude code_graph tests for now
exclude = if !run_tmux_tests, do: [tmux: true, code_graph: true], else: [code_graph: true]
ExUnit.start(exclude: exclude)

# No Mox mocks defined here currently
# Add other mocks here if needed
