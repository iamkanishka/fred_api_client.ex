defmodule FredApiClient.Sources do
  @moduledoc """
  FRED Sources API — 3 endpoints.

  A source is an organisation that publishes data on FRED, such as
  the Federal Reserve Board or the Bureau of Labor Statistics.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/#Sources
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  @type config :: Client.config()

  @doc """
  Get all sources of economic data (paginated).

  ## Parameters
  - `limit` (optional, 1–1000, default 1000)
  - `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_sources(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_sources(params \\ %{}, config), do: Client.get("/fred/sources", params, config)

  @doc """
  Get a single source of economic data.

  ## Parameters
  - `source_id` (required) — e.g. `1`
  - `realtime_start` / `realtime_end` (optional)

  ## Example

      iex> FredApiClient.Sources.get_source(%{source_id: 1}, config)
      {:ok, %{"sources" => [%{"id" => 1, "name" => "Board of Governors of the Federal Reserve System", ...}]}}
  """
  @spec get_source(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_source(params, config), do: Client.get("/fred/source", params, config)

  @doc """
  Get the releases for a source (paginated).

  ## Parameters
  - `source_id` (required)
  - `limit` / `offset` / `order_by` / `sort_order` / `realtime_start` / `realtime_end` (optional)
  """
  @spec get_source_releases(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_source_releases(params, config), do: Client.get("/fred/source/releases", params, config)
end
