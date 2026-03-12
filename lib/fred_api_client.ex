defmodule FredApiClient do
  @moduledoc """
  A fully-typed Elixir client for the Federal Reserve Economic Data (FRED) API.

  Covers all 36 endpoints across 7 groups: Categories, Releases, Series,
  Sources, Tags, GeoFRED Maps, and bulk API v2.

  ## Installation

  Add `fred_api_client` to your `mix.exs` dependencies:

      def deps do
        [
          {:fred_api_client, "~> 0.1"}
        ]
      end

  ## Configuration

  ### Application config (recommended for Phoenix / OTP apps)

      # config/config.exs
      config :fred_api_client,
        api_key: System.get_env("FRED_API_KEY"),
        timeout: 30_000

      # config/runtime.exs (for runtime secrets)
      config :fred_api_client,
        api_key: System.fetch_env!("FRED_API_KEY")

  Then call any function without passing config:

      FredApiClient.Series.get_observations(%{series_id: "GDP"})

  ### Explicit config (for multi-tenant or test usage)

      config = %{api_key: "your_api_key", timeout: 10_000}
      FredApiClient.Series.get_observations(%{series_id: "GDP"}, config)

  ## Quick Start

      # Get GDP observations
      {:ok, data} = FredApiClient.Series.get_observations(%{
        series_id: "GDP",
        observation_start: "2010-01-01",
        units: "pc1",
        frequency: "q"
      })

      # Search for series
      {:ok, results} = FredApiClient.Series.search(%{
        search_text: "unemployment rate",
        limit: 5,
        order_by: "popularity",
        sort_order: "desc"
      })

      # Get geographic data
      {:ok, geo} = FredApiClient.Maps.get_regional_data(%{
        series_group: "882",
        region_type: "state",
        date: "2023-01-01",
        season: "NSA",
        units: "Dollars"
      })

  ## Error Handling

      case FredApiClient.Series.get_observations(%{series_id: "INVALID"}) do
        {:ok, data} ->
          IO.inspect(data["observations"])

        {:error, %FredApiClient.Error{code: code, message: message}} ->
          Logger.error("FRED Error [\#{code}]: \#{message}")
      end

  ## API Reference

  - `FredApiClient.Categories` — 6 endpoints
  - `FredApiClient.Releases`   — 9 endpoints
  - `FredApiClient.Series`     — 10 endpoints
  - `FredApiClient.Sources`    — 3 endpoints
  - `FredApiClient.Tags`       — 3 endpoints
  - `FredApiClient.Maps`       — 4 endpoints (GeoFRED)
  - `FredApiClient.V2`         — 1 endpoint (bulk)
  """

  alias FredApiClient.{Categories, Releases, Series, Sources, Tags, Maps, V2}

  # ---------------------------------------------------------------------------
  # Config helpers
  # ---------------------------------------------------------------------------

  @doc false
  def config do
    api_key =
      Application.get_env(:fred_api_client, :api_key) ||
        raise ArgumentError, """
        FredApiClient requires an API key. Set it in your config:

            config :fred_api_client, api_key: System.get_env("FRED_API_KEY")

        Or pass it explicitly:

            FredApiClient.Series.get_observations(%{series_id: "GDP"}, %{api_key: "YOUR_KEY"})
        """

    %{
      api_key: api_key,
      base_url: Application.get_env(:fred_api_client, :base_url, "https://api.stlouisfed.org"),
      file_type: Application.get_env(:fred_api_client, :file_type, "json"),
      timeout: Application.get_env(:fred_api_client, :timeout, 30_000)
    }
  end

  # ---------------------------------------------------------------------------
  # Categories — 6 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_category(params, config \\ config()), to: Categories
  defdelegate get_category_children(params, config \\ config()), to: Categories, as: :get_children
  defdelegate get_category_related(params, config \\ config()), to: Categories, as: :get_related
  defdelegate get_category_series(params, config \\ config()), to: Categories, as: :get_series
  defdelegate get_category_tags(params, config \\ config()), to: Categories, as: :get_tags

  defdelegate get_category_related_tags(params, config \\ config()),
    to: Categories,
    as: :get_related_tags

  # ---------------------------------------------------------------------------
  # Releases — 9 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_releases(params \\ %{}, config \\ config()), to: Releases
  defdelegate get_all_release_dates(params \\ %{}, config \\ config()), to: Releases
  defdelegate get_release(params, config \\ config()), to: Releases
  defdelegate get_release_dates(params, config \\ config()), to: Releases
  defdelegate get_release_series(params, config \\ config()), to: Releases
  defdelegate get_release_sources(params, config \\ config()), to: Releases
  defdelegate get_release_tags(params, config \\ config()), to: Releases
  defdelegate get_release_related_tags(params, config \\ config()), to: Releases
  defdelegate get_release_tables(params, config \\ config()), to: Releases

  # ---------------------------------------------------------------------------
  # Series — 10 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_series(params, config \\ config()), to: Series
  defdelegate get_series_categories(params, config \\ config()), to: Series, as: :get_categories
  defdelegate get_series_observations(params, config \\ config()), to: Series, as: :get_observations
  defdelegate get_series_release(params, config \\ config()), to: Series, as: :get_release
  defdelegate search_series(params, config \\ config()), to: Series, as: :search
  defdelegate get_series_search_tags(params, config \\ config()), to: Series, as: :get_search_tags

  defdelegate get_series_search_related_tags(params, config \\ config()),
    to: Series,
    as: :get_search_related_tags

  defdelegate get_series_tags(params, config \\ config()), to: Series, as: :get_tags
  defdelegate get_series_updates(params \\ %{}, config \\ config()), to: Series, as: :get_updates

  defdelegate get_series_vintage_dates(params, config \\ config()),
    to: Series,
    as: :get_vintage_dates

  # ---------------------------------------------------------------------------
  # Sources — 3 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_sources(params \\ %{}, config \\ config()), to: Sources
  defdelegate get_source(params, config \\ config()), to: Sources
  defdelegate get_source_releases(params, config \\ config()), to: Sources

  # ---------------------------------------------------------------------------
  # Tags — 3 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_tags(params \\ %{}, config \\ config()), to: Tags
  defdelegate get_related_tags(params, config \\ config()), to: Tags
  defdelegate get_tags_series(params, config \\ config()), to: Tags, as: :get_series

  # ---------------------------------------------------------------------------
  # Maps / GeoFRED — 4 endpoints
  # ---------------------------------------------------------------------------
  defdelegate get_shapes(params, config \\ config()), to: Maps
  defdelegate get_series_group(params, config \\ config()), to: Maps
  defdelegate get_geo_series_data(params, config \\ config()), to: Maps, as: :get_series_data
  defdelegate get_regional_data(params, config \\ config()), to: Maps

  # ---------------------------------------------------------------------------
  # V2 Bulk — 1 endpoint
  # ---------------------------------------------------------------------------
  defdelegate get_release_observations(params, config \\ config()), to: V2
end
