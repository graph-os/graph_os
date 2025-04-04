defmodule GraphOS.Protocol.MixProject do
  use Mix.Project

  def project do
    [
      app: :graph_os_protocol,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Boundary enforcement
      compilers: [:boundary | Mix.compilers()],
      boundary: boundary()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GraphOS.Protocol.Application, []}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core GraphOS dependencies
      {:graph_os_store, in_umbrella: true},
      {:graph_os_core, in_umbrella: true},
      {:mcp, in_umbrella: true},

      # Protocol-specific dependencies
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:boundary, "~> 0.10", runtime: false},

      # Development and testing
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:meck, "~> 0.9", only: :test}
    ]
  end

  defp boundary do
    [
      default: [
        check: [
          # Allow dependencies on components higher in the hierarchy
          deps: [:graph_os_core, :graph_os_store, :mcp, :tmux, GraphOS.Adapter],
          # Prevent this app from using apps lower in the hierarchy
          apps: [in: [:graph_os_core, :graph_os_store, :mcp, :tmux]]
        ]
      ],
      # Define this boundary's ID for other components to reference
      identifier: :graph_os_protocol,
      # Define public exports from this application
      exports: [
        # Main protocol modules
        GraphOS.Protocol,
        GraphOS.Protocol.GRPC,
        GraphOS.Protocol.JSONRPC,
        GraphOS.Protocol.Plug,
        GraphOS.Protocol.Schema,
        GraphOS.Protocol.Router,
        GraphOS.Protocol.Adapter,
        # Auth modules (needed for the new authentication system)
        GraphOS.Protocol.Auth,
        GraphOS.Protocol.Auth.Secret,
        GraphOS.Protocol.Auth.Plug
      ]
    ]
  end
end
