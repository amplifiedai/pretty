defmodule Pretty.MixProject do
  use Mix.Project

  @version "1.0.8"

  def project do
    [
      app: :pretty,
      deps: deps(),
      description: "Inspect values with syntax colors despite your remote console.",
      docs: docs(),
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      homepage_url: "https://github.com/amplifiedai/pretty",
      name: "Pretty",
      package: package(),
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.json": :test],
      source_url: "https://github.com/amplifiedai/pretty",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.24.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14.1", only: :test, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      api_reference: false,
      authors: ["Garth Kidd"],
      canonical: "http://hexdocs.pm/pretty",
      main: "Pretty",
      source_ref: "v#{@version}"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      files: ~w(mix.exs README.md lib test/support),
      licenses: ["Apache 2.0"],
      links: %{
        "Amplified" => "https://www.amplified.ai",
        "GitHub" => "https://github.com/amplifiedai/pretty"
      },
      maintainers: ["Garth Kidd"]
    ]
  end
end
