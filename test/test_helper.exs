ExUnit.start()

# Cachex may already be started by the application supervision tree.
# Handle both cases so the test suite works whether or not the app
# is started before test_helper runs.
case Cachex.start_link(:fred_api_cache, []) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end
