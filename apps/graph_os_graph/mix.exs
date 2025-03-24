defmodule GraphOS.Store.MixProject do
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
      name: "GraphOS.Store",

      # Boundary enforcement
      compilers: [:boundary | Mix.compilers()],
      boundary: boundary()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GraphOS.Store.Application, []},
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
      main: "GraphOS.Store",
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
        GraphOS.Store,
        GraphOS.Store.Node,
        GraphOS.Store.Edge,
        GraphOS.Store.Graph,
        GraphOS.Store.Transaction,
        GraphOS.Store.Operation,
        # Registry for multiple stores
        GraphOS.Store.Registry,
        # Interfaces for other components to use
        GraphOS.Store.Query,
        GraphOS.Store.StoreAdapter,
        # Schema system (public interfaces only)
        GraphOS.Schema,
        # Behaviours
        GraphOS.Store.SchemaBehaviour,
        GraphOS.Store.Protocol,
        # Schema implementations
        GraphOS.Store.Schema.Protobuf
      ]
    ]
  end
end
