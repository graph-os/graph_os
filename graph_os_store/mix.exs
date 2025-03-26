defmodule GraphOS.Store.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/graph-os/graph_os_store"

  def project do
    [
      app: :graph_os_graph,
      version: @version,
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package info
      description: "Store library for GraphOS",
      package: package(),
      docs: docs(),
      name: "GraphOS.Store",

      # Boundary enforcement
      compilers: [:boundary | Mix.compilers()]
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
      {:uuid_v7, "~> 0.6"}
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
end
