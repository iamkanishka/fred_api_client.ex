# FredApiClient

[![Hex.pm](https://img.shields.io/hexpm/v/fred_api_client.svg)](https://hex.pm/packages/fred_api_client)
[![CI](https://github.com/iamkanishka/fred_api_client/actions/workflows/ci.yml/badge.svg)](https://github.com/iamkanishka/fred_api_client/actions)
[![Coverage](https://codecov.io/gh/iamkanishka/fred_api_client/branch/master/graph/badge.svg)](https://codecov.io/gh/iamkanishka/fred_api_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)

A fully-typed Elixir client for the [Federal Reserve Economic Data (FRED) API](https://fred.stlouisfed.org/docs/api/fred/).

Covers all **36 endpoints** across 7 groups: Categories, Releases, Series, Sources, Tags, GeoFRED Maps, and bulk API v2.

## Installation

Add `fred_api_client` to your `mix.exs`:

```elixir
def deps do
  [
    {:fred_api_client, "~> 0.1"}
  ]
end
```

## Configuration

```elixir
# config/config.exs
config :fred_api_client,
  api_key: System.get_env("FRED_API_KEY")

# config/runtime.exs (recommended for production)
config :fred_api_client,
  api_key: System.fetch_env!("FRED_API_KEY")
```

Get a free API key at https://fred.stlouisfed.org/docs/api/api_key.html

## Usage

```elixir
# Get GDP observations
{:ok, data} = FredApiClient.get_series_observations(%{
  series_id: "GDP",
  observation_start: "2010-01-01",
  units: "pc1",
  frequency: "q"
})

IO.inspect(data["observations"])
# [%{"date" => "2010-01-01", "value" => "3.7"}, ...]

# Search for series
{:ok, results} = FredApiClient.search_series(%{
  search_text: "unemployment rate",
  limit: 5,
  order_by: "popularity",
  sort_order: "desc"
})

# Get all releases
{:ok, releases} = FredApiClient.get_releases(%{limit: 10})

# Get geographic regional data
{:ok, geo} = FredApiClient.get_regional_data(%{
  series_group: "882",
  region_type: "state",
  date: "2023-01-01",
  season: "NSA",
  units: "Dollars"
})
```

## Error Handling

All functions return `{:ok, map()}` or `{:error, %FredApiClient.Error{}}`:

```elixir
case FredApiClient.get_series_observations(%{series_id: "INVALID"}) do
  {:ok, data} ->
    IO.inspect(data["observations"])

  {:error, %FredApiClient.Error{code: code, message: message}} ->
    Logger.error("FRED Error [#{code}]: #{message}")
end
```

## Multi-tenant / Explicit Config

Pass config explicitly to use different API keys per call:

```elixir
config = %{api_key: "user_specific_key", timeout: 10_000}
FredApiClient.get_series_observations(%{series_id: "GDP"}, config)
```

## API Coverage

| Module | Endpoints |
|---|---|
| `FredApiClient.Categories` | `get_category`, `get_children`, `get_related`, `get_series`, `get_tags`, `get_related_tags` |
| `FredApiClient.Releases` | `get_releases`, `get_all_release_dates`, `get_release`, `get_release_dates`, `get_release_series`, `get_release_sources`, `get_release_tags`, `get_release_related_tags`, `get_release_tables` |
| `FredApiClient.Series` | `get_series`, `get_categories`, `get_observations`, `get_release`, `search`, `get_search_tags`, `get_search_related_tags`, `get_tags`, `get_updates`, `get_vintage_dates` |
| `FredApiClient.Sources` | `get_sources`, `get_source`, `get_source_releases` |
| `FredApiClient.Tags` | `get_tags`, `get_related_tags`, `get_series` |
| `FredApiClient.Maps` | `get_shapes`, `get_series_group`, `get_series_data`, `get_regional_data` |
| `FredApiClient.V2` | `get_release_observations` |

## License

MIT — see [LICENSE.txt](LICENSE.txt).
