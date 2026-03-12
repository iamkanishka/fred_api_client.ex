defmodule FredApiClient.V2 do
  @moduledoc """
  FRED Bulk API v2 — 1 endpoint.

  Use this instead of looping `Series.get_observations/2` per series when
  you need all observations for every series in a release at once.

  ## Reference
  https://fred.stlouisfed.org/docs/api/fred/v2/
  """

  alias FredApiClient.Client
  alias FredApiClient.Error

  @type config :: Client.config()

  @doc """
  Get observations for ALL series in a release in a single bulk request.

  Includes full revision history. Significantly more efficient than making
  individual `Series.get_observations/2` calls for each series.

  ## Parameters
  - `release_id` (required) — e.g. `53`
  - `element_id` (optional) — restrict to a subtree
  - `observation_date` (optional) — e.g. `"2023-01-01"`
  - `file_type` (optional) — `"json"` | `"xml"` | `"txt"` | `"xls"` (default `"json"`)

  ## Example

      iex> FredApiClient.V2.get_release_observations(%{release_id: 53, file_type: "json"}, config)
      {:ok, %{...}}
  """
  @spec get_release_observations(map(), config()) :: {:ok, map()} | {:error, Error.t()}
  def get_release_observations(params, config),
    do: Client.get("/fred/v2/release/observations", params, config)
end
