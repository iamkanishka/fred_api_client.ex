defmodule FredAPIClient.Sources do
  @moduledoc """
    FRED Sources API — 3 endpoints. All cached 24h.

  A source is an organisation that publishes data on FRED, such as
  the Federal Reserve Board or the Bureau of Labor Statistics.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Sources
  """

  alias FredAPIClient.Client
  alias FredAPIClient.Error
  alias FredAPIClient.Cache

  @group "sources"

  @type config :: Client.config()

  @doc """
  Get all sources of economic data (paginated) with 24h cache.

  ## Parameters
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_sources(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_sources(params \\ %{}, config) do
    Cache.fetch(Cache.build_key(@group, "get_sources", params), Cache.ttl_24h(), fn ->
      Client.get("/fred/sources", params, config)
    end)
  end

  @doc """
  Get a single source of economic data with 24h Cache.

  ## Parameters
  - `source_id` (required) — e.g. `1`
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredAPIClient.Sources.get_source(%{source_id: 1}, config)
      {:ok, %{"sources" => [%{"id" => 1, "name" => "Board of Governors of the Federal Reserve System", ...}]}}
  """
  @spec get_source(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_source(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_source", params), Cache.ttl_24h(), fn ->
      Client.get("/fred/source", params, config)
    end)
  end

  @doc """
  Get the releases for a source (paginated) with 12h Cache.

  ## Parameters
  - `source_id` (required)
  - `limit` / `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_source_releases(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_source_releases(params, config) do
    Cache.fetch(Cache.build_key(@group, "get_source_releases", params), Cache.ttl_24h(), fn ->
      Client.get("/fred/source/releases", params, config)
    end)
  end
end
