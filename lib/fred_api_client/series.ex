defmodule FredApiClient.Series do
  @moduledoc """
  FRED Series API — 10 endpoints.

  A series is a named sequence of data observations indexed by date.
  The most commonly used endpoint is `get_observations/2` which returns
  the actual numeric values.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Series
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  @type config :: Client.config()

  @doc """
  Get an economic data series by ID.

  ## Parameters
  - `series_id` (required) — e.g. `"GDP"`, `"GNPCA"`, `"UNRATE"`
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Series.get_series(%{series_id: "GNPCA"}, config)
      {:ok, %{"seriess" => [%{"id" => "GNPCA", "title" => "Real Gross National Product", ...}]}}
  """
  @spec get_series(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_series(params, config), do: Client.get("/fred/series", params, config)

  @doc """
  Get the categories for an economic data series.

  ## Parameters
  - `series_id` (required)
  - `realtime_start` / `realtime_end` (optional)
  """
  @spec get_categories(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_categories(params, config), do: Client.get("/fred/series/categories", params, config)

  @doc """
  Get the observations (data values) for an economic data series.

  This is the core endpoint — it returns the actual numeric time-series values.

  ## Parameters
  - `series_id` (required)
  - `observation_start` / `observation_end` (optional) — ISO dates e.g. `"2010-01-01"`
  - `realtime_start` / `realtime_end` (optional)
  - `limit` (optional, 1–100000, default 100000)
  - `offset` / `sort_order` (optional)
  - `units` (optional) — `"lin"` | `"chg"` | `"ch1"` | `"pch"` | `"pc1"` |
    `"pca"` | `"cch"` | `"cca"` | `"log"` (default `"lin"`)
  - `frequency` (optional) — `"d"` | `"w"` | `"bw"` | `"m"` | `"q"` | `"sa"` | `"a"` etc.
  - `aggregation_method` (optional) — `"avg"` | `"sum"` | `"eop"` (default `"avg"`)
  - `output_type` (optional) — `1` | `2` | `3` | `4` (default `1`)
  - `vintage_dates` (optional) — comma-delimited dates

  ## Example

      iex> FredApiClient.Series.get_observations(
      ...>   %{series_id: "GDP", observation_start: "2010-01-01", units: "pc1", frequency: "q"},
      ...>   config
      ...> )
      {:ok, %{"count" => 56, "observations" => [%{"date" => "2010-01-01", "value" => "3.7"}, ...]}}
  """
  @spec get_observations(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_observations(params, config), do: Client.get("/fred/series/observations", params, config)

  @doc """
  Get the release for an economic data series.

  ## Parameters
  - `series_id` (required)
  - `realtime_start` / `realtime_end` (optional)
  """
  @spec get_release(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release(params, config), do: Client.get("/fred/series/release", params, config)

  @doc """
  Search for series matching keywords (paginated).

  ## Parameters
  - `search_text` (required) — e.g. `"consumer price index"`
  - `search_type` (optional) — `"full_text"` | `"series_id"` (default `"full_text"`)
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` (optional)
  - `filter_variable` / `filter_value` / `tag_names` / `exclude_tag_names` (optional)

  ## Example

      iex> FredApiClient.Series.search(%{search_text: "unemployment rate", limit: 5, order_by: "popularity"}, config)
      {:ok, %{"count" => 312, "seriess" => [...]}}
  """
  @spec search(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def search(params, config), do: Client.get("/fred/series/search", params, config)

  @doc """
  Get the tags for a series search.

  ## Parameters
  - `series_search_text` (required)
  - `tag_names` / `tag_group_id` / `tag_search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_search_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_search_tags(params, config), do: Client.get("/fred/series/search/tags", params, config)

  @doc """
  Get the related tags for a series search.

  ## Parameters
  - `series_search_text` (required)
  - `tag_names` (required) — semicolon-delimited
  - `exclude_tag_names` / `tag_group_id` / `tag_search_text` (optional)
  """
  @spec get_search_related_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_search_related_tags(params, config),
    do: Client.get("/fred/series/search/related_tags", params, config)

  @doc """
  Get the tags for an economic data series.

  ## Parameters
  - `series_id` (required)
  - `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_tags(params, config), do: Client.get("/fred/series/tags", params, config)

  @doc """
  Get economic data series sorted by when observations were last updated.

  ## Parameters
  - `filter_value` (optional) — `"macro"` | `"regional"` | `"all"` (default `"all"`)
  - `limit` (optional, 1–100, default 100)
  - `offset` / `realtime_start` / `realtime_end` / `start_time` / `end_time` (optional)
  """
  @spec get_updates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_updates(params \\ %{}, config), do: Client.get("/fred/series/updates", params, config)

  @doc """
  Get the dates when a series' data values were revised or new values released.

  ## Parameters
  - `series_id` (required)
  - `sort_order` / `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Series.get_vintage_dates(%{series_id: "GNPCA", sort_order: "asc"}, config)
      {:ok, %{"vintage_dates" => ["1958-12-21", "1959-02-19", ...]}}
  """
  @spec get_vintage_dates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_vintage_dates(params, config), do: Client.get("/fred/series/vintagedates", params, config)
end
