defmodule FredApiClient.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/iamkanishka/fred_api_client.ex"

  def project do
    [
      app: :fred_api_client,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],

      # Aliases
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {FredApiClient.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},
      # JSON
      {:jason, "~> 1.4"},
      {:cachex, "~> 3.6"},
      # Dev & test
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A fully-typed Elixir client for the Federal Reserve Economic Data (FRED) API. " <>
      "Covers all 36 endpoints: categories, releases, series, sources, tags, GeoFRED and bulk v2." <>
      "Includes intelligent Cachex-backed caching with frequency-aware TTLs."
  end

  defp package do
    [
      name: "fred_api_client",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "FRED API Docs" => "https://fred.stlouisfed.org/docs/api/fred/"
      },
      maintainers: ["Kanishka Naik"],
      keywords: [
        "fred",
        "fred-api",
        "federal-reserve",
        "economic-data",
        "stlouisfed",
        "api-client",
        "elixir",
        "economics",
        "finance",
        "financial-data",
        "macroeconomics",
        "gdp",
        "inflation",
        "interest-rates",
        "time-series",
        "observations",
        "geofred",
        "regional-data"
      ],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.txt CHANGELOG.md)
    ]
  end

  defp docs do
    [
      name: "FredApiClient",
      source_url: @source_url,
      homepage_url: @source_url,
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        API: [
          FredApiClient.Categories,
          FredApiClient.Releases,
          FredApiClient.Series,
          FredApiClient.Sources,
          FredApiClient.Tags,
          FredApiClient.Maps,
          FredApiClient.V2
        ],
        HTTP: [FredApiClient.Client, FredApiClient.Error],
        Types: [FredApiClient.Types]
      ]
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "compile"],

      # Quality checks
      quality: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ],

      # Testing
      test: ["test"],
      "test.coverage": ["coveralls.html"],

      # Documentation
      docs: ["docs"],
      "docs.open": ["docs", "cmd open doc/index.html"],

      # CI
      ci: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "dialyzer",
        "test --cover"
      ]
    ]
  end
end
