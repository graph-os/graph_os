defmodule GraphOS.MCP.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/graph_os"

  def project do
    [
      app: :graph_os_mcp,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package info
      description: "Model Context Protocol implementation for GraphOS",
      package: package(),
      docs: docs(),
      name: "GraphOS.MCP"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GraphOS.MCP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:graph_os_graph, in_umbrella: true},
      {:graph_os_core, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:bandit, "~> 1.2"},
      {:file_system, "~> 1.1"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "GraphOS.MCP",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
