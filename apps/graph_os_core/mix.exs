defmodule GraphOS.Core.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/graph_os"

  def project do
    [
      app: :graph_os_core,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Hex package info
      description: "Core OS functions for GraphOS",
      package: package(),
      docs: docs(),
      name: "GraphOS.Core",
      # Boundary enforcement
      compilers: [:boundary | Mix.compilers()],
      boundary: boundary()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GraphOS.Core.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:graph_os_store, in_umbrella: true},
      {:mcp, in_umbrella: true},
      {:boundary, "~> 0.9", runtime: false},
      {:gen_stage, "~> 1.2"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
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
      main: "GraphOS.Core",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp boundary do
    [
      default: [
        check: [
          # Only allow dependencies on apps higher in the hierarchy
          deps: [:graph_os_graph, :mcp, :tmux],
          # Prevent this app from using apps lower in the hierarchy
          apps: [in: [:graph_os_graph, :mcp, :tmux]]
        ]
      ],
      # Define this boundary's ID for other components to reference
      identifier: :graph_os_core,
      # Define public exports from this application
      exports: [
        # Component system
        GraphOS.Component,
        GraphOS.Component.Builder,
        GraphOS.Component.Context,
        GraphOS.Component.Pipeline,
        GraphOS.Component.Registry,
        # Core functionality
        GraphOS.Core,
        GraphOS.Core.CodeGraph,
        GraphOS.Core.Executable,
        GraphOS.Core.AccessControl,
        GraphOS.Core.GitIntegration,
        GraphOS.Core.SystemInfo,
        # Connection and Graph functionality
        GraphOS.Conn,
        GraphOS.ConnSupervisor,
        GraphOS.Store,
        GraphOS.Store.SubscriptionBehaviour,
        GraphOS.Registry,
        GraphOS.Server
      ]
    ]
  end
end
