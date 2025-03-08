defmodule GraphOS.Standalone.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/graph-os/graph_os"

  def project do
    [
      app: :graph_os,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "GraphOS",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core GraphOS components from GitHub repos
      {:graph_os_graph, github: "graph-os/graph_os_graph", tag: "v0.1.0"},
      {:graph_os_core, github: "graph-os/graph_os_core", tag: "v0.1.0"},
      {:graph_os_mcp, github: "graph-os/graph_os_mcp", tag: "v0.1.0"},
      {:graph_os_distributed, github: "graph-os/graph_os_distributed", tag: "v0.1.0"},

      # Development tools
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        "Graph": ~r/GraphOS\.Graph\..*/,
        "Core": ~r/GraphOS\.Core\..*/,
        "MCP": ~r/GraphOS\.MCP\..*/,
        "Distributed": ~r/GraphOS\.Distributed\..*/
      ]
    ]
  end
end
