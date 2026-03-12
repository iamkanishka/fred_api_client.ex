defmodule FredApiClient.Releases do
  @moduledoc """
  FRED Releases API — 9 endpoints.

  A release is a named publication of economic data (e.g. "Gross Domestic Product").
  Releases contain one or more series, have dated publication schedules, and belong
  to one or more sources.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Releases
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  @type config :: Client.config()

  @doc """
  Get all releases of economic data (paginated).

  ## Parameters
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_releases(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_releases(params \\ %{}, config), do: Client.get("/fred/releases", params, config)

  @doc """
  Get release dates for all releases.

  ## Parameters
  - `include_release_dates_with_no_data` (optional, default `false`)
  - `limit` / `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_all_release_dates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_all_release_dates(params \\ %{}, config),
    do: Client.get("/fred/releases/dates", params, config)

  @doc """
  Get a single release of economic data.

  ## Parameters
  - `release_id` (required) — e.g. `53`
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Releases.get_release(%{release_id: 53}, config)
      {:ok, %{"releases" => [%{"id" => 53, "name" => "Gross Domestic Product", ...}]}}
  """
  @spec get_release(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release(params, config), do: Client.get("/fred/release", params, config)

  @doc """
  Get release dates for a specific release.

  ## Parameters
  - `release_id` (required)
  - `limit` (optional, 1–10000, default 10000)
  - `sort_order` / `include_release_dates_with_no_data` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_release_dates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_dates(params, config), do: Client.get("/fred/release/dates", params, config)

  @doc """
  Get the series on a release (paginated).

  ## Parameters
  - `release_id` (required)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  - `filter_variable` / `filter_value` / `tag_names` / `exclude_tag_names` (optional)
  """
  @spec get_release_series(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_series(params, config), do: Client.get("/fred/release/series", params, config)

  @doc """
  Get the sources for a release.

  ## Parameters
  - `release_id` (required)
  - `realtime_start` / `realtime_end` (optional)
  """
  @spec get_release_sources(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_sources(params, config), do: Client.get("/fred/release/sources", params, config)

  @doc """
  Get the tags for a release.

  ## Parameters
  - `release_id` (required)
  - `tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_release_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_tags(params, config), do: Client.get("/fred/release/tags", params, config)

  @doc """
  Get the related tags for a release.

  ## Parameters
  - `release_id` (required)
  - `tag_names` (required) — semicolon-delimited
  - `exclude_tag_names` / `tag_group_id` / `search_text` (optional)
  """
  @spec get_release_related_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_related_tags(params, config),
    do: Client.get("/fred/release/related_tags", params, config)

  @doc """
  Get the release table trees for a given release (hierarchical element tree).

  ## Parameters
  - `release_id` (required)
  - `element_id` (optional) — drill into a specific subtree
  - `include_observation_values` (optional, default `false`)
  - `observation_date` (optional)

  ## Example

      iex> FredApiClient.Releases.get_release_tables(%{release_id: 53, element_id: 12886}, config)
      {:ok, %{"elements" => %{"12887" => %{"name" => "...", "children" => [...]}}}}
  """
  @spec get_release_tables(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_tables(params, config), do: Client.get("/fred/release/tables", params, config)
end
