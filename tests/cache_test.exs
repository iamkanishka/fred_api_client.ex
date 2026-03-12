defmodule FredApiClient.CacheTest do
  use ExUnit.Case, async: false

  alias FredApiClient.Cache

  setup do
    # Clear cache between tests
    Cache.clear()
    :ok
  end

  describe "fetch/3" do
    test "calls fun on cache miss and stores result" do
      call_count = :counters.new(1, [])

      fun = fn ->
        :counters.add(call_count, 1, 1)
        {:ok, %{"categories" => [%{"id" => 125}]}}
      end

      assert {:ok, %{"categories" => _}} = Cache.fetch("test:key:1", :timer.seconds(60), fun)
      assert :counters.get(call_count, 1) == 1
    end

    test "returns cached value on second call without calling fun" do
      call_count = :counters.new(1, [])

      fun = fn ->
        :counters.add(call_count, 1, 1)
        {:ok, %{"value" => "cached"}}
      end

      Cache.fetch("test:key:2", :timer.seconds(60), fun)
      Cache.fetch("test:key:2", :timer.seconds(60), fun)

      assert :counters.get(call_count, 1) == 1
    end

    test "does not cache error responses" do
      call_count = :counters.new(1, [])

      fun = fn ->
        :counters.add(call_count, 1, 1)
        {:error, %FredApiClient.HTTP.Error{code: 400, status: 400, message: "Bad Request"}}
      end

      Cache.fetch("test:key:3", :timer.seconds(60), fun)
      Cache.fetch("test:key:3", :timer.seconds(60), fun)

      assert :counters.get(call_count, 1) == 2
    end
  end

  describe "observations_ttl/1" do
    test "returns :skip for daily frequency" do
      assert Cache.observations_ttl("d") == :skip
    end

    test "returns :skip for weekly frequencies" do
      for freq <- ~w(w bw wef weth wew wetu wem wesu wesa bwew bwem) do
        assert Cache.observations_ttl(freq) == :skip, "Expected :skip for #{freq}"
      end
    end

    test "returns 1h TTL for monthly frequency" do
      assert Cache.observations_ttl("m") == :timer.hours(1)
    end

    test "returns 6h TTL for quarterly frequency" do
      assert Cache.observations_ttl("q") == :timer.hours(6)
    end

    test "returns 6h TTL for semi-annual frequency" do
      assert Cache.observations_ttl("sa") == :timer.hours(6)
    end

    test "returns 6h TTL for annual frequency" do
      assert Cache.observations_ttl("a") == :timer.hours(6)
    end

    test "returns :skip for unknown frequency" do
      assert Cache.observations_ttl("unknown") == :skip
    end

    test "returns :skip for nil/empty frequency" do
      assert Cache.observations_ttl("") == :skip
    end
  end

  describe "build_key/3" do
    test "produces stable key for same params" do
      key1 = Cache.build_key("series", "get_series", %{series_id: "GDP"})
      key2 = Cache.build_key("series", "get_series", %{series_id: "GDP"})
      assert key1 == key2
    end

    test "produces different keys for different params" do
      key1 = Cache.build_key("series", "get_series", %{series_id: "GDP"})
      key2 = Cache.build_key("series", "get_series", %{series_id: "UNRATE"})
      refute key1 == key2
    end

    test "key is order-independent for params map" do
      key1 = Cache.build_key("series", "get_obs", %{series_id: "GDP", frequency: "q"})
      key2 = Cache.build_key("series", "get_obs", %{frequency: "q", series_id: "GDP"})
      assert key1 == key2
    end

    test "excludes nil values from key hash" do
      key1 = Cache.build_key("series", "get_series", %{series_id: "GDP", realtime_start: nil})
      key2 = Cache.build_key("series", "get_series", %{series_id: "GDP"})
      assert key1 == key2
    end

    test "key format is fred:{group}:{function}:{hash}" do
      key = Cache.build_key("categories", "get_category", %{category_id: 125})
      assert String.starts_with?(key, "fred:categories:get_category:")
    end
  end

  describe "invalidate/1" do
    test "removes a specific key from cache" do
      Cache.fetch("test:inv:1", :timer.seconds(60), fn -> {:ok, %{"data" => 1}} end)
      Cache.invalidate("test:inv:1")

      call_count = :counters.new(1, [])
      Cache.fetch("test:inv:1", :timer.seconds(60), fn ->
        :counters.add(call_count, 1, 1)
        {:ok, %{"data" => 2}}
      end)

      assert :counters.get(call_count, 1) == 1
    end
  end

  describe "clear/0" do
    test "removes all keys from cache" do
      Cache.fetch("test:clear:1", :timer.seconds(60), fn -> {:ok, %{}} end)
      Cache.fetch("test:clear:2", :timer.seconds(60), fn -> {:ok, %{}} end)
      Cache.clear()

      {:ok, size} = Cachex.size(:fred_api_cache)
      assert size == 0
    end
  end
end
