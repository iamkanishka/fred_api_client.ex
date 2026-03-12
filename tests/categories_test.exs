defmodule FredApiClient.CategoriesTest do
  use ExUnit.Case, async: true

  alias FredApiClient.Categories

  setup do
    bypass = Bypass.open()
    config = %{api_key: "test_key", base_url: "http://localhost:#{bypass.port}", file_type: "json", timeout: 5_000}
    {:ok, bypass: bypass, config: config}
  end

  test "get_category/2 returns category by id", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "GET", "/fred/category", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, ~s({"categories":[{"id":125,"name":"Trade Balance","parent_id":13}]}))
    end)

    assert {:ok, %{"categories" => [%{"id" => 125, "name" => "Trade Balance"}]}} =
             Categories.get_category(%{category_id: 125}, config)
  end

  test "get_children/2 returns child categories", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "GET", "/fred/category/children", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, ~s({"categories":[{"id":16,"name":"Exports","parent_id":13}]}))
    end)

    assert {:ok, %{"categories" => [%{"id" => 16}]}} =
             Categories.get_children(%{category_id: 13}, config)
  end

  test "get_series/2 returns paginated series", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "GET", "/fred/category/series", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, ~s({"count":32,"limit":10,"offset":0,"seriess":[]}))
    end)

    assert {:ok, %{"count" => 32}} =
             Categories.get_series(%{category_id: 125, limit: 10}, config)
  end
end
