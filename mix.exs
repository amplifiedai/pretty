defmodule Pretty.MixProject do
  use Mix.Project

  def project do
    [
      app: :pretty,
      deps: deps(),
      description: "Inspect values with syntax colors despite your remote console.",
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      homepage_url: "https://github.com/amplifiedai/pretty",
      name: "Pretty",
      package: package(),
      preferred_cli_env: preferred_cli_env(),
      source_url: "https://github.com/amplifiedai/pretty",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "1.0.5"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.3", only: [:dev, :test]},
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
      main: "Pretty"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{
        "Amplified" => "https://www.amplified.ai",
        "GitHub" => "https://github.com/amplifiedai/pretty"
      }
    ]
  end

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
