defmodule FredAPIClient.Client do
  @moduledoc """
  Low-level HTTP client for the FRED API.

  Handles authentication, query-string building, timeout, error parsing,
  and automatic retry with exponential backoff on rate limit errors.

  ## FRED API Rate Limit

  The FRED API enforces a limit of **120 requests per minute** per API key.
  Exceeding it returns HTTP `429 Too Many Requests`.

  This client handles 429 automatically with exponential backoff:

  | Attempt | Wait before retry |
  |---------|-------------------|
  | 1st     | 20s               |
  | 2nd     | 40s               |
  | 3rd     | 60s               |
  | 4th     | (give up)         |

  The default of 3 retries with a 20s base delay means requests recover
  well within the 60s rate-limit window. Both values are configurable:

      config :fred_api_client,
        rate_limit_max_retries: 3,
        rate_limit_base_delay_ms: 20_000

  ## Retry on transient errors

  In addition to 429, the client retries on:
  - `503 Service Unavailable` — server overload
  - `:timeout` transport errors — network blip

  Non-retryable errors (400, 404, 423, 500) are returned immediately.
  """

  alias FredAPIClient.Error

  @base_url "https://api.stlouisfed.org"
  @default_timeout 30_000
  @default_file_type "json"
  @default_max_retries 3
  @default_base_delay_ms 20_000

  # HTTP status codes that are retryable
  @retryable_statuses [429, 503]

  # HTTP status codes that should never be retried
  @terminal_statuses [400, 404, 423, 500]

  @type config :: %{
          required(:api_key) => String.t(),
          optional(:base_url) => String.t(),
          optional(:file_type) => String.t(),
          optional(:timeout) => non_neg_integer()
        }

  @doc """
  Performs a GET request to the given FRED API `path` with `params`.

  Automatically appends `api_key` and `file_type` to every request.
  Retries automatically on `429 Too Many Requests` and `503` with
  exponential backoff.

  ## Examples

      iex> Client.get("/fred/category", %{category_id: 125}, config)
      {:ok, %{"categories" => [%{"id" => 125, ...}]}}

      iex> Client.get("/fred/series", %{series_id: "INVALID"}, config)
      {:error, %FredAPIClient.Error{code: 400, status: 400, message: "..."}}
  """
  @spec get(String.t(), map(), config()) :: {:ok, map() | list()} | {:error, Error.t()}
  def get(path, params \\ %{}, config) do
    max_retries =
      Application.get_env(:fred_api_client, :rate_limit_max_retries, @default_max_retries)

    do_get(path, params, config, 0, max_retries)
  end

  # ---------------------------------------------------------------------------
  # Private — retry loop
  # ---------------------------------------------------------------------------

  defp do_get(path, params, config, attempt, max_retries) do
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

      {:ok, %Req.Response{status: status}}
      when status in @retryable_statuses and attempt < max_retries ->
        delay = backoff_delay(status, attempt)
        :timer.sleep(delay)
        do_get(path, params, config, attempt + 1, max_retries)

      {:ok, %Req.Response{status: status, body: _body}} when status in @retryable_statuses ->
        # Exhausted retries
        {:error,
         %Error{
           code: status,
           status: status,
           message: rate_limit_message(status, max_retries)
         }}

      {:ok, %Req.Response{status: status, body: body}} when status in @terminal_statuses ->
        {:error, parse_error_body(body, status)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, parse_error_body(body, status)}

      {:error, %Req.TransportError{reason: :timeout}} when attempt < max_retries ->
        delay = backoff_delay(:timeout, attempt)
        :timer.sleep(delay)
        do_get(path, params, config, attempt + 1, max_retries)

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error,
         %Error{
           code: 408,
           status: nil,
           message:
             "Request timed out after #{Map.get(config, :timeout, @default_timeout)}ms (#{max_retries} retries exhausted)"
         }}

      {:error, exception} ->
        {:error, %Error{code: 0, status: nil, message: Exception.message(exception)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — backoff strategy
  # ---------------------------------------------------------------------------

  # 429: use exponential backoff with base delay from config
  # The FRED rate limit window is 60s (120 req/min)
  # Base 20s * attempt gives: 20s, 40s, 60s — safely within the window
  defp backoff_delay(429, attempt) do
    base = Application.get_env(:fred_api_client, :rate_limit_base_delay_ms, @default_base_delay_ms)
    base * (attempt + 1)
  end

  # 503: shorter backoff — server overload clears faster
  defp backoff_delay(503, attempt) do
    base = 5_000
    min(base * (attempt + 1), 30_000)
  end

  # Timeout: short backoff
  defp backoff_delay(:timeout, attempt) do
    base = 3_000
    min(base * (attempt + 1), 15_000)
  end

  defp rate_limit_message(429, max_retries) do
    "FRED API rate limit exceeded (120 req/min). Retried #{max_retries} times. " <>
      "Consider adding delays between requests or enabling caching."
  end

  defp rate_limit_message(503, max_retries) do
    "FRED API service unavailable. Retried #{max_retries} times."
  end

  # ---------------------------------------------------------------------------
  # Private — URL building & response parsing
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
