defmodule FredApiClient.SeriesTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Series
  alias FredApiClient.Error

  setup do
    bypass = Bypass.open()

    config = %{
      api_key: "test_key",
      base_url: "http://localhost:#{bypass.port}",
      file_type: "json",
      timeout: 5_000
    }

    {:ok, bypass: bypass, config: config}
  end

  describe "get_series/2" do
    test "returns series metadata", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          ~s({"seriess":[{"id":"GNPCA","title":"Real Gross National Product"}]})
        )
      end)

      assert {:ok, %{"seriess" => [%{"id" => "GNPCA"}]}} =
               Series.get_series(%{series_id: "GNPCA"}, config)
    end
  end

  describe "get_observations/2" do
    test "returns observations with date and value", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series/observations", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "observations": [
            {"date": "2023-01-01", "value": "26854.60"},
            {"date": "2023-04-01", "value": "27065.28"}
          ]
        }))
      end)

      assert {:ok,
              %{
                "count" => 2,
                "observations" => [%{"date" => "2023-01-01", "value" => "26854.60"} | _]
              }} =
               Series.get_observations(%{series_id: "GDP"}, config)
    end

    test "sends optional parameters in query string", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series/observations", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["units"] == "pc1"
        assert query["frequency"] == "q"
        assert query["observation_start"] == "2010-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count":0,"observations":[]}))
      end)

      Series.get_observations(
        %{series_id: "GDP", units: "pc1", frequency: "q", observation_start: "2010-01-01"},
        config
      )
    end
  end

  describe "search/2" do
    test "returns paginated search results", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series/search", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["search_text"] == "unemployment rate"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count":312,"limit":5,"offset":0,"seriess":[]}))
      end)

      assert {:ok, %{"count" => 312}} =
               Series.search(%{search_text: "unemployment rate", limit: 5}, config)
    end
  end

  describe "get_vintage_dates/2" do
    test "returns list of vintage date strings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series/vintagedates", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"vintage_dates":["1958-12-21","1959-02-19"]}))
      end)

      assert {:ok, %{"vintage_dates" => ["1958-12-21" | _]}} =
               Series.get_vintage_dates(%{series_id: "GNPCA"}, config)
    end
  end

  describe "error handling" do
    test "returns Error struct on invalid series_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series/observations", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, ~s({"error_code":400,"error_message":"Bad Request."}))
      end)

      assert {:error, %Error{code: 400}} =
               Series.get_observations(%{series_id: "INVALID"}, config)
    end
  end
end
