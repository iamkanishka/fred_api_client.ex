defmodule FredApiClient.Client do
  @moduledoc """
  Low-level HTTP client for the FRED API.

  Handles authentication, query-string building, timeout, and error parsing.
  All public API modules delegate to this module.
  """

  alias FredApiClient.Error

  @base_url "https://api.stlouisfed.org"
  @default_timeout 30_000
  @default_file_type "json"

  @type config :: %{
          required(:api_key) => String.t(),
          optional(:base_url) => String.t(),
          optional(:file_type) => String.t(),
          optional(:timeout) => non_neg_integer()
        }

  @doc """
  Performs a GET request to the given FRED API `path` with `params`.

  Automatically appends `api_key` and `file_type` to every request.

  ## Examples

      iex> FredApiClient.Client.get("/fred/category", %{category_id: 125}, config)
      {:ok, %{"categories" => [%{"id" => 125, ...}]}}

      iex> FredApiClient.Client.get("/fred/series", %{series_id: "INVALID"}, config)
      {:error, %FredApiClient.Error{code: 400, status: 400, message: "..."}}
  """
  @spec get(String.t(), map(), config()) ::
          {:ok, map() | list()} | {:error, Error.t()}
  def get(path, params \\ %{}, config) do
    url = build_url(path, params, config)

    req_opts = [
      url: url,
      receive_timeout: Map.get(config, :timeout, @default_timeout),
      headers: [{"accept", "application/json"}],
      decode_body: false
    ]

    case Req.get(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        decode_body(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        error = parse_error_body(body, status)
        {:error, error}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error,
         %Error{
           code: 408,
           status: nil,
           message: "Request timed out after #{Map.get(config, :timeout, @default_timeout)}ms"
         }}

      {:error, exception} ->
        {:error, %Error{code: 0, status: nil, message: Exception.message(exception)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_url(path, params, config) do
    base = Map.get(config, :base_url, @base_url)
    file_type = Map.get(config, :file_type, @default_file_type)
    api_key = Map.fetch!(config, :api_key)

    query_params =
      params
      |> Map.put(:api_key, api_key)
      |> Map.put(:file_type, file_type)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    uri = URI.parse("#{base}#{path}")
    %{uri | query: URI.encode_query(query_params)} |> URI.to_string()
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, _} ->
        {:error, %Error{code: 0, status: nil, message: "Failed to decode JSON response"}}
    end
  end

  defp decode_body(body), do: {:ok, body}

  defp parse_error_body(body, status) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error_code" => code, "error_message" => message}} ->
        %Error{code: code, status: status, message: message}

      _ ->
        %Error{code: status, status: status, message: "HTTP #{status}"}
    end
  end

  defp parse_error_body(_, status),
    do: %Error{code: status, status: status, message: "HTTP #{status}"}
end
