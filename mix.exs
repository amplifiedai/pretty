defmodule Pretty.MixProject do
  use Mix.Project

  @source_url "https://github.com/amplifiedai/pretty"
  @version "1.0.8"

  def project do
    [
      app: :pretty,
      version: @version,
      name: "Pretty",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.json": :test],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls]
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14.1", only: :test, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Pretty",
      canonical: "http://hexdocs.pm/pretty",
      source_url: @source_url,
      source_ref: "v#{@version}",
      homepage_url: @source_url,
      formatters: ["html"],
      api_reference: false
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      description: "Inspect values with syntax colors despite your remote console.",
      files: ~w(mix.exs README.md LICENSE.md lib test/support),
      maintainers: ["Garth Kidd"],
      licenses: ["Apache-2.0"],
      links: %{
        "Amplified" => "https://www.amplified.ai",
        "GitHub" => @source_url
      }
    ]
  end
end
