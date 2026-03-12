defmodule FredApiClient.Categories do
  @moduledoc """
  FRED Categories API — 6 endpoints.

  Categories form a hierarchical tree used to organise FRED series.
  The root category has `id: 0`. Navigate with `get_children/2` and find
  series within a leaf category using `get_series/2`.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Categories
  """

  alias FredApiClient.Client

  alias FredApiClient.Error

  @type config :: Client.config()

  # ---------------------------------------------------------------------------
  # GET /fred/category
  # ---------------------------------------------------------------------------

  @doc """
  Get a single category by ID.

  ## Parameters
  - `category_id` (required) — e.g. `125`

  ## Example

      iex> FredApiClient.Categories.get_category(%{category_id: 125}, config)
      {:ok, %{"categories" => [%{"id" => 125, "name" => "Trade Balance", "parent_id" => 13}]}}
  """
  @spec get_category(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_category(params, config), do: Client.get("/fred/category", params, config)

  # ---------------------------------------------------------------------------
  # GET /fred/category/children
  # ---------------------------------------------------------------------------

  @doc """
  Get the child categories for a specified parent category.

  ## Parameters
  - `category_id` (required)
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Categories.get_children(%{category_id: 13}, config)
      {:ok, %{"categories" => [%{"id" => 16, "name" => "Exports", "parent_id" => 13}, ...]}}
  """
  @spec get_children(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_children(params, config), do: Client.get("/fred/category/children", params, config)

  # ---------------------------------------------------------------------------
  # GET /fred/category/related
  # ---------------------------------------------------------------------------

  @doc """
  Get the related categories for a category.

  ## Parameters
  - `category_id` (required)
  - `realtime_start` / `realtime_end` (optional)
  """
  @spec get_related(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_related(params, config), do: Client.get("/fred/category/related", params, config)

  # ---------------------------------------------------------------------------
  # GET /fred/category/series
  # ---------------------------------------------------------------------------

  @doc """
  Get the series in a category (paginated).

  ## Parameters
  - `category_id` (required)
  - `limit` (optional, 1–1000, default 1000)
  - `offset` (optional)
  - `order_by` (optional) — `"series_id"` | `"title"` | `"units"` | `"frequency"` |
    `"seasonal_adjustment"` | `"realtime_start"` | `"realtime_end"` |
    `"last_updated"` | `"observation_start"` | `"observation_end"` |
    `"popularity"` | `"group_popularity"`
  - `sort_order` (optional) — `"asc"` | `"desc"`
  - `filter_variable` / `filter_value` (optional)
  - `tag_names` (optional) — semicolon-delimited e.g. `"trade;goods"`
  - `exclude_tag_names` (optional)

  ## Example

      iex> FredApiClient.Categories.get_series(%{category_id: 125, limit: 5, order_by: "popularity", sort_order: "desc"}, config)
      {:ok, %{"count" => 32, "seriess" => [...]}}
  """
  @spec get_series(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_series(params, config), do: Client.get("/fred/category/series", params, config)

  # ---------------------------------------------------------------------------
  # GET /fred/category/tags
  # ---------------------------------------------------------------------------

  @doc """
  Get the tags for a category.

  ## Parameters
  - `category_id` (required)
  - `tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_tags(params, config), do: Client.get("/fred/category/tags", params, config)

  # ---------------------------------------------------------------------------
  # GET /fred/category/related_tags
  # ---------------------------------------------------------------------------

  @doc """
  Get the related tags for a category.

  ## Parameters
  - `category_id` (required)
  - `tag_names` (required) — semicolon-delimited e.g. `"services;quarterly"`
  - `exclude_tag_names` / `tag_group_id` / `search_text` (optional)
  - `limit` / `offset` / `order_by` / `sort_order` (optional)
  """
  @spec get_related_tags(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_related_tags(params, config),
    do: Client.get("/fred/category/related_tags", params, config)
end
