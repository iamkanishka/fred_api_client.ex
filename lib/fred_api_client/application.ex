defmodule FredApiClient.Application do
  @moduledoc false
  use Application

  @cache_name :fred_api_cache

  @impl true
  def start(_type, _args) do
    cache_name = Application.get_env(:fred_api_client, :cache_name, @cache_name)

    children = build_children(cache_name)

    opts = [strategy: :one_for_one, name: FredApiClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Always start Cachex — even when cache_enabled: false — because the Cache
  # module calls Cachex.get/put/stream unconditionally and will crash if the
  # named process doesn't exist. cache_enabled: false is checked at call-time
  # inside Cache.fetch/3, so the process must always be present.
  #
  # In test env the supervisor starts Cachex first; test_helper.exs then
  # handles {:already_started, pid} gracefully via a case match.
  defp build_children(cache_name) do
    [
      {Cachex, name: cache_name, stats: cache_stats_enabled?()}
    ]
  end

  # Only enable Cachex stats tracking in non-test environments.
  # Stats collection adds minor overhead and is not needed during tests.
  defp cache_stats_enabled? do
    Application.get_env(:fred_api_client, :cache_stats, false)
  end
end
