defmodule FredAPIClient.ReleasesTest do
  use ExUnit.Case, async: true

  alias FredAPIClient.Releases
  alias FredAPIClient.Error

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

  describe "get_releases/2" do
    test "returns paginated list of all releases", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/releases", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "realtime_start": "2013-08-14",
          "realtime_end": "2013-08-14",
          "order_by": "release_id",
          "sort_order": "asc",
          "count": 2,
          "offset": 0,
          "limit": 1000,
          "releases": [
            {"id": 9, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Advance Monthly Sales for Retail and Food Services", "press_release": true, "link": "http://www.census.gov/retail/"},
            {"id": 10, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Consumer Price Index", "press_release": true, "link": "http://www.bls.gov/cpi/"}
          ]
        }))
      end)

      assert {:ok, %{"releases" => [%{"id" => 9} | _], "count" => 2}} =
               Releases.get_releases(%{}, config)
    end

    test "sends optional pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/releases", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "10"
        assert query["order_by"] == "name"
        assert query["sort_order"] == "asc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "releases": []}))
      end)

      Releases.get_releases(%{limit: 10, order_by: "name", sort_order: "asc"}, config)
    end

    test "returns Error on invalid request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/releases", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, ~s({"error_code": 400, "error_message": "Bad Request."}))
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Releases.get_releases(%{limit: 0}, config)
    end
  end

  describe "get_all_release_dates/2" do
    test "returns release dates across all releases", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/releases/dates", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "release_dates": [
            {"release_id": 9, "release_name": "Advance Monthly Sales for Retail and Food Services", "date": "2013-08-13"},
            {"release_id": 10, "release_name": "Consumer Price Index", "date": "2013-08-15"}
          ]
        }))
      end)

      assert {:ok, %{"release_dates" => [%{"release_id" => 9} | _]}} =
               Releases.get_all_release_dates(%{}, config)
    end

    test "sends include_release_dates_with_no_data param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/releases/dates", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["include_release_dates_with_no_data"] == "true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "release_dates": []}))
      end)

      Releases.get_all_release_dates(%{include_release_dates_with_no_data: true}, config)
    end
  end

  describe "get_release/2" do
    test "returns metadata for a specific release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "53"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "releases": [
            {"id": 53, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Gross Domestic Product", "press_release": true, "link": "http://www.bea.gov/newsreleases/national/gdp/gdpnewsrelease.htm"}
          ]
        }))
      end)

      assert {:ok, %{"releases" => [%{"id" => 53, "name" => "Gross Domestic Product"}]}} =
               Releases.get_release(%{release_id: 53}, config)
    end

    test "returns Error for invalid release_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable release_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Releases.get_release(%{release_id: 999_999}, config)
    end
  end

  describe "get_release_dates/2" do
    test "returns publication dates for a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/dates", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "82"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "release_dates": [
            {"release_id": 82, "date": "1997-02-10"},
            {"release_id": 82, "date": "1998-02-10"}
          ]
        }))
      end)

      assert {:ok, %{"release_dates" => [%{"release_id" => 82} | _]}} =
               Releases.get_release_dates(%{release_id: 82}, config)
    end

    test "sends optional sort_order param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/dates", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["sort_order"] == "desc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "release_dates": []}))
      end)

      Releases.get_release_dates(%{release_id: 82, sort_order: "desc"}, config)
    end
  end

  describe "get_release_series/2" do
    test "returns series belonging to a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/series", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "51"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 1,
          "limit": 1000,
          "offset": 0,
          "seriess": [
            {"id": "PCPI06037", "title": "Per Capita Personal Income in Los Angeles County, CA"}
          ]
        }))
      end)

      assert {:ok, %{"seriess" => [%{"id" => "PCPI06037"}]}} =
               Releases.get_release_series(%{release_id: 51}, config)
    end

    test "sends tag_names filter param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/series", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_names"] == "usa;annual"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "seriess": []}))
      end)

      Releases.get_release_series(%{release_id: 51, tag_names: "usa;annual"}, config)
    end
  end

  describe "get_release_sources/2" do
    test "returns sources for a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/sources", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "51"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "sources": [
            {"id": 3, "realtime_start": "1776-07-04", "realtime_end": "9999-12-31", "name": "Federal Reserve Bank of Philadelphia", "link": "http://www.philadelphiafed.org/"}
          ]
        }))
      end)

      assert {:ok, %{"sources" => [%{"id" => 3, "name" => "Federal Reserve Bank of Philadelphia"}]}} =
               Releases.get_release_sources(%{release_id: 51}, config)
    end
  end

  describe "get_release_tags/2" do
    test "returns tags for a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "86"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "tags": [
            {"name": "commercial paper", "group_id": "gen", "notes": "", "created": "2012-02-27 10:18:19-06", "popularity": 55, "series_count": 18},
            {"name": "frb", "group_id": "src", "notes": "Federal Reserve Board", "created": "2012-02-27 10:18:19-06", "popularity": 83, "series_count": 18}
          ]
        }))
      end)

      assert {:ok, %{"tags" => [%{"name" => "commercial paper"} | _]}} =
               Releases.get_release_tags(%{release_id: 86}, config)
    end

    test "sends optional search_text and tag_group_id params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["search_text"] == "federal"
        assert query["tag_group_id"] == "src"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "tags": []}))
      end)

      Releases.get_release_tags(
        %{release_id: 86, search_text: "federal", tag_group_id: "src"},
        config
      )
    end
  end

  describe "get_release_related_tags/2" do
    test "returns related tags for a release and tag set", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/related_tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "86"
        assert query["tag_names"] == "sa;foreign"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 1,
          "tags": [
            {"name": "commercial paper", "group_id": "gen", "popularity": 55, "series_count": 2}
          ]
        }))
      end)

      assert {:ok, %{"tags" => [%{"name" => "commercial paper"}]}} =
               Releases.get_release_related_tags(%{release_id: 86, tag_names: "sa;foreign"}, config)
    end
  end

  describe "get_release_tables/2" do
    test "returns hierarchical element tree for a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/tables", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "53"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "elements": {
            "12886": {
              "element_id": 12886,
              "release_id": 53,
              "series_id": "DGDSRL1A225NBEA",
              "parent_id": 12885,
              "line": "2",
              "type": "series",
              "name": "Goods",
              "level": "1",
              "children": []
            }
          }
        }))
      end)

      assert {:ok, %{"elements" => %{"12886" => %{"release_id" => 53}}}} =
               Releases.get_release_tables(%{release_id: 53}, config)
    end

    test "sends element_id for subtree drill-down", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/tables", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "53"
        assert query["element_id"] == "12886"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"elements": {}}))
      end)

      Releases.get_release_tables(%{release_id: 53, element_id: 12_886}, config)
    end

    test "sends include_observation_values param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/release/tables", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["include_observation_values"] == "true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"elements": {}}))
      end)

      Releases.get_release_tables(%{release_id: 53, include_observation_values: true}, config)
    end
  end
end
