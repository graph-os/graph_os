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
      name: "GraphOS.Core"
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
      {:graph_os_graph, in_umbrella: true},
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
end
