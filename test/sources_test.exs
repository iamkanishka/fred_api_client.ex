defmodule FredApiClient.SourcesTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Sources
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

  describe "get_sources/2" do
    test "returns all data sources", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/sources", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "realtime_start": "2013-08-14",
          "realtime_end": "2013-08-14",
          "order_by": "source_id",
          "sort_order": "asc",
          "count": 2,
          "offset": 0,
          "limit": 1000,
          "sources": [
            {"id": 1, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Board of Governors of the Federal Reserve System", "link": "http://www.federalreserve.gov/"},
            {"id": 3, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Federal Reserve Bank of Philadelphia", "link": "http://www.philadelphiafed.org/"}
          ]
        }))
      end)

      assert {:ok,
              %{
                "sources" => [
                  %{"id" => 1, "name" => "Board of Governors of the Federal Reserve System"} | _
                ],
                "count" => 2
              }} = Sources.get_sources(%{}, config)
    end

    test "sends optional pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/sources", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "10"
        assert query["order_by"] == "name"
        assert query["sort_order"] == "asc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "sources": []}))
      end)

      Sources.get_sources(%{limit: 10, order_by: "name", sort_order: "asc"}, config)
    end

    test "sends optional realtime params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/sources", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["realtime_start"] == "2000-01-01"
        assert query["realtime_end"] == "2013-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "sources": []}))
      end)

      Sources.get_sources(%{realtime_start: "2000-01-01", realtime_end: "2013-01-01"}, config)
    end

    test "returns Error on bad request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/sources", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, ~s({"error_code": 400, "error_message": "Bad Request."}))
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Sources.get_sources(%{limit: 0}, config)
    end
  end

  describe "get_source/2" do
    test "returns a single source by id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["source_id"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "realtime_start": "2013-08-14",
          "realtime_end": "2013-08-14",
          "sources": [
            {
              "id": 1,
              "realtime_start": "1776-07-04",
              "realtime_end": "9999-12-31",
              "name": "Board of Governors of the Federal Reserve System",
              "link": "http://www.federalreserve.gov/",
              "notes": "The Federal Reserve Board of Governors in Washington DC."
            }
          ]
        }))
      end)

      assert {:ok,
              %{
                "sources" => [
                  %{
                    "id" => 1,
                    "name" => "Board of Governors of the Federal Reserve System"
                  }
                ]
              }} = Sources.get_source(%{source_id: 1}, config)
    end

    test "sends optional realtime params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["source_id"] == "1"
        assert query["realtime_start"] == "2000-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"sources": []}))
      end)

      Sources.get_source(%{source_id: 1, realtime_start: "2000-01-01"}, config)
    end

    test "returns Error for unknown source_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable source_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Sources.get_source(%{source_id: 999_999}, config)
    end
  end

  describe "get_source_releases/2" do
    test "returns releases for a given source", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source/releases", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["source_id"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "limit": 1000,
          "offset": 0,
          "releases": [
            {"id": 13, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "G.17 Industrial Production and Capacity Utilization", "press_release": true},
            {"id": 14, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "G.19 Consumer Credit", "press_release": true}
          ]
        }))
      end)

      assert {:ok, %{"releases" => [%{"id" => 13} | _], "count" => 2}} =
               Sources.get_source_releases(%{source_id: 1}, config)
    end

    test "sends pagination and sort params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source/releases", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["source_id"] == "1"
        assert query["limit"] == "5"
        assert query["order_by"] == "name"
        assert query["sort_order"] == "asc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "releases": []}))
      end)

      Sources.get_source_releases(
        %{source_id: 1, limit: 5, order_by: "name", sort_order: "asc"},
        config
      )
    end

    test "returns Error for unknown source_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/source/releases", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable source_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Sources.get_source_releases(%{source_id: 999_999}, config)
    end
  end
end
