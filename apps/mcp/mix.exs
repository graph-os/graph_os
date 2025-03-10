defmodule MCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcp,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {MCP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Internal dependencies
      {:graph_os_core, in_umbrella: true},
      {:graph_os_dev, in_umbrella: true},
      {:tmux, in_umbrella: true},
      # UUID generation
      {:uuid, "~> 1.1"},
      # HTTP client for MCP client
      {:finch, "~> 0.16"},
      # Web server
      {:plug, "~> 1.14"},
      {:bandit, "~> 1.5"},
      {:cowboy, "~> 2.10"},
      {:plug_cowboy, "~> 2.6"},
      # JSON handling
      {:jason, "~> 1.4"},
      # JSON Schema validation
      {:ex_json_schema, "~> 0.10.0"}
    ]
  end
end
