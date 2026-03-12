defmodule FredApiClient.MapsTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Maps
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

  describe "get_shapes/2" do
    test "returns GeoJSON FeatureCollection for state shapes", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/shapes/file", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["shape"] == "state"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "MultiPolygon", "coordinates": []},
              "properties": {"name": "Alabama", "fips": "01"}
            }
          ]
        }))
      end)

      assert {:ok,
              %{
                "type" => "FeatureCollection",
                "features" => [%{"properties" => %{"name" => "Alabama"}} | _]
              }} =
               Maps.get_shapes(%{shape: "state"}, config)
    end

    test "sends shape param for county shapes", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/shapes/file", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["shape"] == "county"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"type": "FeatureCollection", "features": []}))
      end)

      Maps.get_shapes(%{shape: "county"}, config)
    end

    test "returns Error for invalid shape type", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/shapes/file", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable shape is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Maps.get_shapes(%{shape: "invalid"}, config)
    end
  end

  describe "get_series_group/2" do
    test "returns series group metadata", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/series/group", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["series_id"] == "SMU56000000500000001a"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "series_group": {
            "title": "All Employees: Total Private",
            "region_type": "state",
            "series_group": "1223",
            "season": "NSA",
            "units": "Thousands of Persons",
            "frequency": "a",
            "min_date": "1990-01-01",
            "max_date": "2013-01-01"
          }
        }))
      end)

      assert {:ok,
              %{
                "series_group" => %{
                  "title" => "All Employees: Total Private",
                  "region_type" => "state",
                  "frequency" => "a"
                }
              }} = Maps.get_series_group(%{series_id: "SMU56000000500000001a"}, config)
    end

    test "returns Error for unknown series_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/series/group", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable series_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Maps.get_series_group(%{series_id: "INVALID"}, config)
    end
  end

  describe "get_series_data/2" do
    test "returns regional data for a series at a given date", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/series/data", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["series_id"] == "WIPCPI"
        assert query["date"] == "2012-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "meta": {
            "title": "Per Capita Personal Income",
            "region": "state",
            "seasonality": "Not Seasonally Adjusted",
            "units": "Dollars",
            "frequency": "Annual",
            "data": {
              "2012-01-01": [
                {"region": "Wisconsin", "code": "WI", "value": "44281", "series_id": "WIPCPI"}
              ]
            }
          }
        }))
      end)

      assert {:ok,
              %{
                "meta" => %{
                  "region" => "state",
                  "data" => %{"2012-01-01" => [%{"region" => "Wisconsin"}]}
                }
              }} =
               Maps.get_series_data(%{series_id: "WIPCPI", date: "2012-01-01"}, config)
    end

    test "sends start_date optional param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/series/data", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["start_date"] == "2010-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"meta": {"data": {}}}))
      end)

      Maps.get_series_data(%{series_id: "WIPCPI", start_date: "2010-01-01"}, config)
    end
  end

  describe "get_regional_data/2" do
    test "returns regional observations for a series group", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/regional/data", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["series_group"] == "882"
        assert query["region_type"] == "state"
        assert query["date"] == "2013-01-01"
        assert query["season"] == "NSA"
        assert query["units"] == "Dollars"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "meta": {
            "title": "Per Capita Personal Income",
            "region": "state",
            "seasonality": "Not Seasonally Adjusted",
            "units": "Dollars",
            "frequency": "Annual",
            "data": {
              "2013-01-01": [
                {"region": "Alabama", "code": "01", "value": "36132", "series_id": "ALPCPI"}
              ]
            }
          }
        }))
      end)

      assert {:ok,
              %{
                "meta" => %{
                  "data" => %{"2013-01-01" => [%{"region" => "Alabama", "value" => "36132"}]}
                }
              }} =
               Maps.get_regional_data(
                 %{
                   series_group: "882",
                   region_type: "state",
                   date: "2013-01-01",
                   season: "NSA",
                   units: "Dollars"
                 },
                 config
               )
    end

    test "sends optional frequency and transformation params", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/regional/data", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["frequency"] == "a"
        assert query["transformation"] == "lin"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"meta": {"data": {}}}))
      end)

      Maps.get_regional_data(
        %{
          series_group: "882",
          region_type: "state",
          date: "2013-01-01",
          season: "NSA",
          units: "Dollars",
          frequency: "a",
          transformation: "lin"
        },
        config
      )
    end

    test "returns Error when required params are missing", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/geofred/regional/data", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable series_group is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Maps.get_regional_data(
                 %{region_type: "state", date: "2013-01-01", season: "NSA", units: "Dollars"},
                 config
               )
    end
  end
end
