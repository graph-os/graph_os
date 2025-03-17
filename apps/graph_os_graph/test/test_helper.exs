# Load support files for testing
Code.require_file("support/graph_factory.ex", __DIR__)

# Exclude incomplete implementations unless explicitly enabled
run_incomplete = System.get_env("MIX_RUN_INCOMPLETE") == "true"
exclude = if run_incomplete, do: [], else: [:incomplete_implementation]

ExUnit.start(exclude: exclude)
