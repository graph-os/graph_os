defmodule GraphOS.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/graph-os/graph_os_umbrella"

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "GraphOS",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      aliases: aliases()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:protobuf, "~> 0.14.1"},
      {:boundary, "~> 0.9", runtime: false}
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
        "Distributed": ~r/GraphOS\.Distributed\..*/,
        "Livebook": ~r/GraphOS\.Livebook\..*/,
        "Phoenix": ~r/GraphOS\.Phoenix\..*/
      ]
    ]
  end

  defp aliases do
    [
      # Run formatter on all apps
      format: ["format", "cmd mix format --check-formatted"],
      # Run tests for all apps
      test: ["cmd mix test"],
      # Run dialyzer
      dialyzer: ["cmd mix dialyzer"],
      # Clean umbrella
      clean: ["cmd mix clean"]
    ]
  end
end
