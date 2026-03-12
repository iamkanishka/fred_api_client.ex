defmodule FredApiClient.Maps do
  @moduledoc """
  GeoFRED Maps API — 4 endpoints.

  GeoFRED provides geographic/regional variants of FRED series,
  allowing you to retrieve data broken down by US state, county, MSA, etc.

  ## Reference
  https://fred.stlouisfed.org/docs/api/geofred/
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  @type config :: Client.config()

  @doc """
  Get geographic shape files (GeoJSON FeatureCollection).

  ## Parameters
  - `shape` (required) — `"bea"` | `"msa"` | `"frb"` | `"necta"` | `"state"` |
    `"country"` | `"county"` | `"censusregion"` | `"censusdivision"`

  ## Example

      iex> FredApiClient.Maps.get_shapes(%{shape: "state"}, config)
      {:ok, %{"type" => "FeatureCollection", "features" => [...]}}
  """
  @spec get_shapes(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_shapes(params, config), do: Client.get("/geofred/shapes/file", params, config)

  @doc """
  Get series group metadata — title, region type, frequency and date range.

  ## Parameters
  - `series_id` (required) — e.g. `"SMU56000000500000001a"`

  ## Example

      iex> FredApiClient.Maps.get_series_group(%{series_id: "SMU56000000500000001a"}, config)
      {:ok, %{"series_group" => %{"title" => "...", "region_type" => "state", "min_date" => "...", "max_date" => "..."}}}
  """
  @spec get_series_group(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_series_group(params, config), do: Client.get("/geofred/series/group", params, config)

  @doc """
  Get series regional data for a specific date or date range.

  ## Parameters
  - `series_id` (required)
  - `date` (optional) — e.g. `"2012-01-01"`
  - `start_date` (optional)

  ## Example

      iex> FredApiClient.Maps.get_series_data(%{series_id: "WIPCPI", date: "2012-01-01"}, config)
      {:ok, %{"meta" => %{"data" => %{"WI" => %{"value" => "44281", "series_id" => "WIPCPI"}}}}}
  """
  @spec get_series_data(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_series_data(params, config), do: Client.get("/geofred/series/data", params, config)

  @doc """
  Get regional data for a series group.

  ## Parameters
  - `series_group` (required) — e.g. `"882"`
  - `region_type` (required) — `"state"` | `"county"` | `"msa"` etc.
  - `date` (required) — e.g. `"2013-01-01"`
  - `season` (required) — `"SA"` | `"NSA"` | `"SSA"` | `"SAAR"` | `"NSAAR"`
  - `units` (required) — e.g. `"Dollars"`
  - `frequency` / `transformation` (optional)

  ## Example

      iex> FredApiClient.Maps.get_regional_data(
      ...>   %{series_group: "882", region_type: "state", date: "2013-01-01", season: "NSA", units: "Dollars"},
      ...>   config
      ...> )
      {:ok, %{"meta" => %{"data" => %{"01" => [%{"region" => "Alabama", "value" => "36132", ...}]}}}}
  """
  @spec get_regional_data(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_regional_data(params, config), do: Client.get("/geofred/regional/data", params, config)
end
