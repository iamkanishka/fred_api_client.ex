defmodule FredApiClient.ErrorTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Error

  describe "Error struct" do
    test "is a defexception with code, status, and message fields" do
      error = %Error{code: 400, status: 400, message: "Bad Request"}
      assert error.code == 400
      assert error.status == 400
      assert error.message == "Bad Request"
    end

    test "status can be nil for network/timeout errors" do
      error = %Error{code: 0, status: nil, message: "Connection refused"}
      assert is_nil(error.status)
    end

    test "message/1 formats as 'FRED API Error [code]: message'" do
      error = %Error{code: 400, status: 400, message: "Bad Request"}
      assert Exception.message(error) == "FRED API Error [400]: Bad Request"
    end

    test "message/1 works for 404 not found" do
      error = %Error{code: 404, status: 404, message: "Not Found"}
      assert Exception.message(error) == "FRED API Error [404]: Not Found"
    end

    test "message/1 works for 429 rate limit" do
      error = %Error{code: 429, status: 429, message: "Too Many Requests"}
      assert Exception.message(error) == "FRED API Error [429]: Too Many Requests"
    end

    test "message/1 works when status is nil" do
      error = %Error{code: 0, status: nil, message: "timeout"}
      assert Exception.message(error) == "FRED API Error [0]: timeout"
    end

    test "is raiseable as an exception" do
      assert_raise Error, "FRED API Error [500]: Internal Server Error", fn ->
        raise Error, code: 500, status: 500, message: "Internal Server Error"
      end
    end
  end
end

defmodule FredApiClient.V2Test do
  use ExUnit.Case, async: true

  alias FredApiClient.V2
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

  describe "get_release_observations/2" do
    test "returns bulk observations for all series in a release", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "53"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({
          "vintage_date": "2013-08-14",
          "release_id": 53,
          "elements": {
            "GDPC1": {
              "series_id": "GDPC1",
              "observations": [
                {"date": "2013-01-01", "value": "15902.1"},
                {"date": "2013-04-01", "value": "16003.5"}
              ]
            }
          }
        }))
      end)

      assert {:ok,
              %{
                "release_id" => 53,
                "elements" => %{
                  "GDPC1" => %{"observations" => [%{"date" => "2013-01-01"} | _]}
                }
              }} = V2.get_release_observations(%{release_id: 53}, config)
    end

    test "sends optional element_id param for subtree restriction", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["release_id"] == "53"
        assert query["element_id"] == "12886"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"release_id": 53, "elements": {}}))
      end)

      V2.get_release_observations(%{release_id: 53, element_id: 12_886}, config)
    end

    test "sends optional observation_date param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["observation_date"] == "2023-01-01"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"release_id": 53, "elements": {}}))
      end)

      V2.get_release_observations(%{release_id: 53, observation_date: "2023-01-01"}, config)
    end

    test "sends optional file_type param", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["file_type"] == "json"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"release_id": 53, "elements": {}}))
      end)

      V2.get_release_observations(%{release_id: 53, file_type: "json"}, config)
    end

    test "returns Error for invalid release_id", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          ~s({"error_code": 400, "error_message": "Bad Request. Variable release_id is not one of the allowed values."})
        )
      end)

      assert {:error, %Error{code: 400, status: 400}} =
               V2.get_release_observations(%{release_id: 999_999}, config)
    end

    test "is not cached — makes fresh HTTP call on every invocation", %{
      bypass: bypass,
      config: config
    } do
      # V2.get_release_observations is explicitly excluded from caching (large bulk payload).
      # Two calls must produce two HTTP requests — no Cachex involvement.
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/fred/v2/release/observations", fn conn ->
        :counters.add(call_count, 1, 1)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"release_id": 53, "elements": {}}))
      end)

      V2.get_release_observations(%{release_id: 53}, config)
      V2.get_release_observations(%{release_id: 53}, config)

      assert :counters.get(call_count, 1) == 2
    end
  end
end
