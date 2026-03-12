defmodule FredAPIClient.Error do
  @moduledoc """
  Represents an error returned by the FRED API or a network failure.

  ## Fields
  - `:code` — FRED API error code, or HTTP status code on non-2xx responses
  - `:status` — HTTP status code (`nil` for network/timeout errors)
  - `:message` — Human-readable error description
  """

  @type t :: %__MODULE__{
          code: non_neg_integer(),
          status: non_neg_integer() | nil,
          message: String.t()
        }

  defexception [:code, :status, :message]

  @impl true
  def message(%__MODULE__{code: code, message: msg}),
    do: "FRED API Error [#{code}]: #{msg}"
end
