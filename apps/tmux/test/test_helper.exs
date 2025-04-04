# Only run tmux tests if MIX_USE_TMUX=true is set
# By default, we'll skip tmux tests
run_tmux_tests = System.get_env("MIX_USE_TMUX") == "true"

# Exclude tmux tests unless explicitly enabled
exclude = if !run_tmux_tests, do: [tmux: true], else: []
ExUnit.start(exclude: exclude)
