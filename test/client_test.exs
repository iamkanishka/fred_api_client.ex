defmodule FredApiClient.ClientTest do
  use ExUnit.Case, async: true

  alias FredApiClient.{Client, Error}

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

  describe "get/3" do
    test "returns decoded JSON on 200", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/category", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          ~s({"categories":[{"id":125,"name":"Trade Balance","parent_id":13}]})
        )
      end)

      assert {:ok, %{"categories" => [%{"id" => 125}]}} =
               Client.get("/fred/category", %{category_id: 125}, config)
    end

    test "appends api_key and file_type to every request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/category", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["api_key"] == "test_key"
        assert query["file_type"] == "json"
        assert query["category_id"] == "125"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"categories":[]}))
      end)

      Client.get("/fred/category", %{category_id: 125}, config)
    end

    test "returns Error on FRED API 400 error response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/series", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code":400,"error_message":"Bad Request. Variable series_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               Client.get("/fred/series", %{series_id: "INVALID"}, config)
    end

    test "returns Error on non-JSON error body", %{bypass: bypass, config: config} do
      # Must use 200, not 500: a 5xx response triggers the retry middleware
      # (rate_limit_max_retries: 2 in test.exs = 3 total attempts), which
      # violates Bypass.expect_once's single-request expectation.
      # A 200 with a non-JSON body exercises the same JSON parse-error path.
      Bypass.expect_once(bypass, "GET", "/fred/series", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{")
      end)

      assert {:error, %Error{}} =
               Client.get("/fred/series", %{}, config)
    end

    test "excludes nil values from query string", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/category", fn conn ->
        query = URI.decode_query(conn.query_string)
        refute Map.has_key?(query, "realtime_start")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"categories":[]}))
      end)

      Client.get("/fred/category", %{category_id: 125, realtime_start: nil}, config)
    end
  end
end
