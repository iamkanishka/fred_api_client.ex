defmodule FredApiClient.Tags do
  @moduledoc """
  FRED Tags API — 3 endpoints.

  Tags are attributes assigned to series, grouped by type:
  `freq` (frequency), `gen` (general), `geo` (geography),
  `geot` (geography type), `rls` (release), `seas` (seasonality), `src` (source).

  ## Cache strategy

  | Endpoint         | Cached | TTL  | Reason                                |
  |------------------|--------|------|---------------------------------------|
  | get_tags         | ✅     | 12h  | Tag vocabulary rarely changes         |
  | get_related_tags | ✅     | 12h  | Related tag mappings rarely change    |
  | get_series       | ❌     | —    | Tag combo results are query-dependent |

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Tags
  """

  alias FredApiClient.Client
  alias FredApiClient.Error
  alias FredApiClient.Cache

  @group "tags"

  @type config :: Client.config()

  @doc """
  Get all tags, or search/filter tags  with 12h Cache.

  ## Parameters
  - `tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Tags.get_tags(%{tag_group_id: "geo", search_text: "united states"}, config)
      {:ok, %{"tags" => [%{"name" => "usa", "group_id" => "geo", "popularity" => 100, ...}]}}
  """
  @spec get_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_tags(params \\ %{}, config) do
    Cache.fetch(Cache.build_key(@group, "get_tags", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/tags", params, config)
    end)
  end

  @doc """
  Get the related tags for one or more tags with  12h Cache.

  ## Parameters
  - `tag_names` (required) — semicolon-delimited e.g. `"nation;nsa"`
  - `exclude_tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_related_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_related_tags(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_related_tags", params), Cache.ttl_12h(), fn ->
      Client.get("/fred/related_tags", params, config)
    end)
  end

  @doc """
  Get the series matching all specified tags (paginated).

  ## Parameters
  - `tag_names` (required) — series must match ALL tags; semicolon-delimited
  - `exclude_tag_names` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Tags.get_series(%{tag_names: "nation;nsa", order_by: "popularity", sort_order: "desc"}, config)
      {:ok, %{"count" => 4521, "seriess" => [...]}}
  """
  @spec get_series(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_series(params, config), do: Client.get("/fred/tags/series", params, config)
end
