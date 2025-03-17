defmodule GraphOS.Graph.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/graph-os/graph_os_graph"

  def project do
    [
      app: :graph_os_graph,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package info
      description: "Graph library for GraphOS",
      package: package(),
      docs: docs(),
      name: "GraphOS.Graph",
      
      # Boundary enforcement
      compilers: [:boundary | Mix.compilers()],
      boundary: boundary()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:boundary, "~> 0.10", runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"}
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
      main: "GraphOS.Graph",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
  
  defp boundary do
    [
      default: [
        check: [
          # No dependencies on other GraphOS components (except MCP for serialization)
          deps: [:mcp],
          # Prevent this app from using apps higher in the hierarchy
          apps: [in: [:mcp]]
        ]
      ],
      # Define this boundary's ID for other components to reference
      identifier: :graph_os_graph,
      # Define public exports from this application
      exports: [
        # Core interfaces
        GraphOS.Graph,
        GraphOS.Graph.Node,
        GraphOS.Graph.Edge,
        GraphOS.Graph.Meta,
        GraphOS.Graph.Transaction,
        GraphOS.Graph.Operation,
        # Interfaces for other components to use
        GraphOS.Graph.Query,
        GraphOS.Graph.Store,
        GraphOS.Graph.Access,
        GraphOS.Graph.Subscription,
        GraphOS.Graph.Protocol,
        # Schema system (public interfaces only)
        GraphOS.Graph.Schema,
        GraphOS.Graph.SchemaBehaviour
      ]
    ]
  end
end
