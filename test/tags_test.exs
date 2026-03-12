defmodule FredApiClient.TagsTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Tags
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

  describe "get_tags/2" do
    test "returns all tags when called with no params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "realtime_start": "2013-08-14",
          "realtime_end": "2013-08-14",
          "order_by": "series_count",
          "sort_order": "desc",
          "count": 2,
          "offset": 0,
          "limit": 1000,
          "tags": [
            {"name": "nation", "group_id": "geo", "notes": "Country Level", "created": "2012-02-27 10:18:19-06", "popularity": 100, "series_count": 105200},
            {"name": "nsa", "group_id": "seas", "notes": "Not seasonally adjusted", "created": "2012-02-27 10:18:19-06", "popularity": 96, "series_count": 100468}
          ]
        }))
      end)

      assert {:ok, %{"tags" => [%{"name" => "nation"} | _], "count" => 2}} =
               Tags.get_tags(%{}, config)
    end

    test "filters tags by tag_group_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_group_id"] == "geo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 1,
          "tags": [{"name": "nation", "group_id": "geo", "popularity": 100, "series_count": 105200}]
        }))
      end)

      assert {:ok, %{"tags" => [%{"group_id" => "geo"}]}} =
               Tags.get_tags(%{tag_group_id: "geo"}, config)
    end

    test "filters tags by search_text", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["search_text"] == "united states"
        assert query["tag_group_id"] == "geo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 1,
          "tags": [{"name": "usa", "group_id": "geo", "popularity": 100, "series_count": 105200}]
        }))
      end)

      assert {:ok, %{"tags" => [%{"name" => "usa"}]}} =
               Tags.get_tags(%{tag_group_id: "geo", search_text: "united states"}, config)
    end

    test "sends pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "5"
        assert query["offset"] == "10"
        assert query["order_by"] == "popularity"
        assert query["sort_order"] == "desc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "tags": []}))
      end)

      Tags.get_tags(%{limit: 5, offset: 10, order_by: "popularity", sort_order: "desc"}, config)
    end

    test "returns Error on bad request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, ~s({"error_code": 400, "error_message": "Bad Request."}))
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Tags.get_tags(%{limit: 0}, config)
    end
  end

  describe "get_related_tags/2" do
    test "returns tags related to a given tag set", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/related_tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_names"] == "nation;nsa"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 2,
          "tags": [
            {"name": "annual", "group_id": "freq", "popularity": 79, "series_count": 12344},
            {"name": "bea", "group_id": "src", "popularity": 72, "series_count": 4984}
          ]
        }))
      end)

      assert {:ok, %{"tags" => [%{"name" => "annual"} | _]}} =
               Tags.get_related_tags(%{tag_names: "nation;nsa"}, config)
    end

    test "sends optional exclude_tag_names and tag_group_id params", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/fred/related_tags", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_names"] == "nation;nsa"
        assert query["exclude_tag_names"] == "discontinued"
        assert query["tag_group_id"] == "freq"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "tags": []}))
      end)

      Tags.get_related_tags(
        %{tag_names: "nation;nsa", exclude_tag_names: "discontinued", tag_group_id: "freq"},
        config
      )
    end

    test "returns Error when tag_names is missing", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/related_tags", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable tag_names is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Tags.get_related_tags(%{}, config)
    end
  end

  describe "get_series/2" do
    test "returns series matching all specified tags", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags/series", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_names"] == "nation;nsa"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "count": 4521,
          "limit": 1000,
          "offset": 0,
          "seriess": [
            {"id": "GNPCA", "title": "Real Gross National Product", "observation_start": "1929-01-01", "observation_end": "2013-01-01", "frequency": "Annual"}
          ]
        }))
      end)

      assert {:ok, %{"count" => 4521, "seriess" => [%{"id" => "GNPCA"}]}} =
               Tags.get_series(%{tag_names: "nation;nsa"}, config)
    end

    test "sends optional exclude_tag_names param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags/series", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["tag_names"] == "nation;nsa"
        assert query["exclude_tag_names"] == "discontinued"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "seriess": []}))
      end)

      Tags.get_series(%{tag_names: "nation;nsa", exclude_tag_names: "discontinued"}, config)
    end

    test "sends order_by and sort_order params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags/series", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["order_by"] == "popularity"
        assert query["sort_order"] == "desc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"count": 0, "seriess": []}))
      end)

      Tags.get_series(
        %{tag_names: "nation;nsa", order_by: "popularity", sort_order: "desc"},
        config
      )
    end

    test "returns Error when tag_names is missing", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/tags/series", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable tag_names is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Tags.get_series(%{}, config)
    end
  end
end
