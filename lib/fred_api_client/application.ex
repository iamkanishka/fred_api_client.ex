defmodule FredApiClient.Application do
  @moduledoc false
  use Application

  @cache_name :fred_api_cache

  @impl true
  def start(_type, _args) do
    cache_name = Application.get_env(:fred_api_client, :cache_name, @cache_name)

    children = [
      {Cachex, name: cache_name}
    ]

    opts = [strategy: :one_for_one, name: FredApiClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
