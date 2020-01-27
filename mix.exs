defmodule Pretty.MixProject do
  use Mix.Project

  def project do
    [
      app: :pretty,
      deps: deps(),
      description: "Inspect values with syntax colors despite your remote console.",
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      homepage_url: "https://github.com/amplified/pretty",
      name: "Pretty",
      preferred_cli_env: preferred_cli_env(),
      source_url: "https://github.com/amplified/pretty",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "1.0.0"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.2", only: [:dev, :test]},
      {:git_hooks, "~> 0.4.1", only: :dev, runtime: false},
      {:ironman, "~> 0.4.3"},
      {:mix_test_watch, "~> 1.0.2", only: :test, runtime: false}
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_apps: [:mix],
      plt_add_deps: [:app_tree]
    ]
  end

  defp docs do
    [
      extras: ["EXPLAIN.md"],
      main: "Pretty"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp preferred_cli_env do
    [
      "coveralls.detail": :test,
      "coveralls.html": :test,
      "coveralls.json": :test,
      "coveralls.post": :test,
      "test.watch": :test,
      coveralls: :test,
      credo: :test,
      docs: :dev
    ]
  end
end