defmodule FredApiClient.Releases do
  @moduledoc """
  FRED Releases API — 9 endpoints.

  A release is a named publication of economic data (e.g. "Gross Domestic Product").
  Releases contain one or more series, have dated publication schedules, and belong
  to one or more sources.

   ## Cache strategy

  | Endpoint              | Cached | TTL  | Reason                          |
  |-----------------------|--------|------|---------------------------------|
  | get_releases          | ✅     | 12h  | Release names rarely change     |
  | get_all_release_dates | ✅     | 1h   | Changes on publish schedule     |
  | get_release           | ✅     | 12h  | Release metadata is static      |
  | get_release_dates     | ✅     | 1h   | Changes on publish schedule     |
  | get_release_series    | ✅     | 12h  | Static series-to-release mapping|
  | get_release_sources   | ✅     | 24h  | Sources never change            |
  | get_release_tags      | ✅     | 12h  | Tags rarely change              |
  | get_release_related_tags | ✅  | 12h  | Tags rarely change              |
  | get_release_tables    | ✅     | 12h  | Table structure is static       |

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Releases
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  alias FredApiClient.Cache

  @group "releases"

  @type config :: Client.config()

  @doc """
  Get all releases of economic data (paginated) Cached 12h.

  ## Parameters
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_releases(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_releases(params \\ %{}, config) do
    Cache.fetch(Cache.build_key(@group, "get_releases", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/releases", params, config)
    end)
  end

  @doc """
  Get release dates for all releases Cached 1h (changes on publish schedule).

  ## Parameters
  - `include_release_dates_with_no_data` (optional, default `false`)
  - `limit` / `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_all_release_dates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_all_release_dates(params \\ %{}, config) do
    Cache.fetch(Cache.build_key(@group, "get_all_release_dates", params), Cache.ttl_1h(), fn ->
      Client.get("/fred/releases/dates", params, config)
    end)
  end

  @doc """
  Get a single release of economic data, Cached 12h.

  ## Parameters
  - `release_id` (required) — e.g. `53`
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Releases.get_release(%{release_id: 53}, config)
      {:ok, %{"releases" => [%{"id" => 53, "name" => "Gross Domestic Product", ...}]}}
  """
  @spec get_release(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/release", params, config)
    end)
  end

  @doc """
  Get release dates for a specific release, Cached 1h (changes on publish schedule).

  ## Parameters
  - `release_id` (required)
  - `limit` (optional, 1–10000, default 10000)
  - `sort_order` / `include_release_dates_with_no_data` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_release_dates(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_dates(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_dates", params), Cache.ttl_1h(), fn ->
      Client.get("/fred/release/dates", params, config)
    end)
  end

  @doc """
  Get the series on a release (paginated), Cached 12h.

  ## Parameters
  - `release_id` (required)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  - `filter_variable` / `filter_value` / `tag_names` / `exclude_tag_names` (optional)
  """
  @spec get_release_series(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_series(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_series", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/release/series", params, config)
    end)
  end

  @doc """
  Get the sources for a release, Cached 24h (sources never change).

  ## Parameters
  - `release_id` (required)
  - `realtime_start` / `realtime_end` (optional)
  """
  @spec get_release_sources(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_sources(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_sources", params), Cache.ttl_24h(), fn ->
      Client.get("/fred/release/sources", params, config)
    end)
  end

  @doc """
  Get the tags for a release, Cached 12h.

  ## Parameters
  - `release_id` (required)
  - `tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_release_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_tags(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_tags", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/release/tags", params, config)
    end)
  end

  @doc """
  Get the related tags for a release, Cached 12h.

  ## Parameters
  - `release_id` (required)
  - `tag_names` (required) — semicolon-delimited
  - `exclude_tag_names` / `tag_group_id` / `search_text` (optional)
  """
  @spec get_release_related_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_related_tags(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_related_tags", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/release/related_tags", params, config)
    end)
  end

  @doc """
  Get the release table trees for a given release (hierarchical element tree),  Cached 12h (structure is static).

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
  def get_release_tables(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_release_tables", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/release/tables", params, config)
    end)
  end
end
