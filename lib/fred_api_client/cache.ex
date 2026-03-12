defmodule FredApiClient.Cache do
  @moduledoc """
  Cachex-backed caching layer for FRED API responses.

  ## TTL Strategy

  TTLs are set based on how frequently FRED actually updates each data type:

  | Data type                        | TTL    | Reason                                   |
  |----------------------------------|--------|------------------------------------------|
  | Category tree                    | 24h    | Essentially static — never changes       |
  | Series metadata                  | 24h    | Title/units/frequency never change       |
  | Series categories/release/tags   | 24h    | Static mappings                          |
  | Release metadata / series        | 12h    | Rarely changes                           |
  | Release tables / sources         | 12h    | Rarely changes                           |
  | Tags                             | 12h    | Rarely changes                           |
  | GeoFRED shapes / series group    | 24h    | Static geographic metadata               |
  | Observations (quarterly/annual)  | 6h     | Updated ~4x/year                         |
  | Series vintage dates             | 6h     | Grows slowly                             |
  | GeoFRED series/regional data     | 2h     | Updated on release schedule              |
  | Observations (monthly)           | 1h     | Updated monthly                          |
  | Release dates                    | 1h     | Changes on publish schedule              |

  ## Not cached (volatile)

  - `Series.search/2`            — free-text query, results vary
  - `Series.get_updates/2`       — volatile by design
  - `Series.get_search_tags/2`   — query-dependent
  - `Tags.get_series/2`          — tag combo results vary
  - `V2.get_release_observations/2` — large bulk payload
  - Observations for `d` / `w` / `bw` frequencies — updated daily/weekly

  ## Cache Key Format

      "fred:{group}:{function}:{stable_params_hash}"

  ## Configuration

      config :fred_api_client,
        cache_enabled: true,
        cache_name: :fred_api_cache,
        ttl_overrides: %{
          series_metadata: :timer.hours(48),
          observations_monthly: :timer.minutes(30)
        }
  """

  @cache_name :fred_api_cache

  # ---------------------------------------------------------------------------
  # TTL constants (milliseconds)
  # ---------------------------------------------------------------------------

  @ttl_24h :timer.hours(24)
  @ttl_12h :timer.hours(12)
  @ttl_6h :timer.hours(6)
  @ttl_2h :timer.hours(2)
  @ttl_1h :timer.hours(1)

  # Frequencies that are too volatile to cache observations for
  @volatile_frequencies ~w(d w bw wef weth wew wetu wem wesu wesa bwew bwem)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetches a value from cache, calling `fun` on miss and storing the result.

  Returns `{:ok, value}` or `{:error, reason}`.

  ## Example

      FredApiClient.Cache.fetch("fred:categories:get_category:125", :timer.hours(24), fn ->
        Client.get("/fred/category", %{category_id: 125}, config)
      end)
  """
  @spec fetch(String.t(), non_neg_integer(), (-> {:ok, any()} | {:error, any()})) ::
          {:ok, any()} | {:error, any()}
  def fetch(key, ttl, fun) do
    if cache_enabled?() do
      case Cachex.get(cache_name(), key) do
        {:ok, nil} ->
          case fun.() do
            {:ok, value} = result ->
              Cachex.put(cache_name(), key, value, ttl: ttl)
              result

            error ->
              error
          end

        {:ok, value} ->
          {:ok, value}

        {:error, _} ->
          fun.()
      end
    else
      fun.()
    end
  end

  @doc "Invalidate a specific cache key."
  @spec invalidate(String.t()) :: {:ok, boolean()}
  def invalidate(key), do: Cachex.del(cache_name(), key)

  @doc "Invalidate all keys matching a prefix pattern e.g. `\"fred:categories:\"`."
  @spec invalidate_prefix(String.t()) :: {:ok, non_neg_integer()}
  def invalidate_prefix(prefix) do
    # Stream only keys (no values), filter by prefix, delete each one.
    # Note: stream! operates on ETS directly — buffer the matching keys first,
    # then delete outside the stream to avoid mutating the table mid-iteration.
    query = Cachex.Query.build(output: :key)

    matching_keys =
      cache_name()
      |> Cachex.stream!(query)
      |> Enum.filter(&String.starts_with?(&1, prefix))

    Enum.each(matching_keys, &Cachex.del(cache_name(), &1))

    {:ok, length(matching_keys)}
  end

  @doc "Clear the entire cache."
  @spec clear() :: {:ok, non_neg_integer()}
  def clear, do: Cachex.clear(cache_name())

  @doc "Return cache stats (hit rate, size, memory)."
  @spec stats() :: {:ok, map()} | {:error, any()}
  def stats, do: Cachex.stats(cache_name())

  # ---------------------------------------------------------------------------
  # TTL helpers — called by API modules
  # ---------------------------------------------------------------------------

  @doc false
  @spec ttl_24h() :: non_neg_integer()
  def ttl_24h, do: ttl_override(:ttl_24h, @ttl_24h)

  @doc false
  @spec ttl_12h() :: non_neg_integer()
  def ttl_12h, do: ttl_override(:ttl_12h, @ttl_12h)

  @doc false
  @spec ttl_6h() :: non_neg_integer()
  def ttl_6h, do: ttl_override(:ttl_6h, @ttl_6h)

  @doc false
  @spec ttl_2h() :: non_neg_integer()
  def ttl_2h, do: ttl_override(:ttl_2h, @ttl_2h)

  @doc false
  @spec ttl_1h() :: non_neg_integer()
  def ttl_1h, do: ttl_override(:ttl_1h, @ttl_1h)

  @doc """
  Returns the appropriate TTL for series observations based on frequency.

  Daily/weekly series are too volatile to cache and return `:skip`.
  """
  @spec observations_ttl(String.t() | nil) :: non_neg_integer() | :skip
  def observations_ttl(frequency) when frequency in @volatile_frequencies, do: :skip
  def observations_ttl("m"), do: ttl_1h()
  def observations_ttl("q"), do: ttl_6h()
  def observations_ttl("sa"), do: ttl_6h()
  def observations_ttl("a"), do: ttl_6h()
  # unknown frequency → don't cache
  def observations_ttl(_), do: :skip

  # ---------------------------------------------------------------------------
  # Cache key builders
  # ---------------------------------------------------------------------------

  @doc "Build a deterministic cache key from a group, function name and params map."
  @spec build_key(String.t(), String.t(), map()) :: String.t()
  def build_key(group, function, params) do
    param_hash =
      params
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> inspect()
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)

    "fred:#{group}:#{function}:#{param_hash}"
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp cache_name do
    Application.get_env(:fred_api_client, :cache_name, @cache_name)
  end

  defp cache_enabled? do
    Application.get_env(:fred_api_client, :cache_enabled, true)
  end

  defp ttl_override(key, default) do
    Application.get_env(:fred_api_client, :ttl_overrides, %{})
    |> Map.get(key, default)
  end
end
