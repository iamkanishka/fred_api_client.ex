import Config

# =============================================================================
# FredApiClient — Base Configuration
#
# This file sets compile-time defaults for all environments.
# Override per-environment in config/dev.exs, config/test.exs, config/prod.exs.
# Put secrets (api_key in production) in config/runtime.exs — never here.
# =============================================================================

config :fred_api_client,
  # ── Required ───────────────────────────────────────────────────────────────
  # Your FRED API key.
  # Get one free at: https://fred.stlouisfed.org/docs/api/api_key.html
  # In production, set this in config/runtime.exs via System.fetch_env!/1
  api_key: System.get_env("FRED_API_KEY"),

  # ── HTTP ───────────────────────────────────────────────────────────────────
  # Base URL for the FRED API. Change only if proxying through your own server.
  base_url: "https://api.stlouisfed.org",

  # Response format. Only "json" is fully supported; "xml" will not be decoded.
  file_type: "json",

  # Per-request timeout in milliseconds.
  timeout: 30_000,

  # ── Caching (Cachex) ───────────────────────────────────────────────────────
  # Toggle caching on/off globally. Overridden to false in config/test.exs.
  cache_enabled: true,

  # Name of the Cachex process started by FredApiClient.Application.
  # Only change this if you have a naming conflict in your supervision tree.
  cache_name: :fred_api_cache,

  # Optional: override individual TTL buckets (all values in milliseconds).
  # Omit this key entirely to use the built-in defaults shown below.
  # Only the buckets you list are changed — the rest keep their defaults.
  #
  # Default TTL reference:
  #   ttl_24h → categories, series metadata, sources, GeoFRED shapes/group
  #   ttl_12h → release metadata/series/tags/tables, tags vocabulary
  #   ttl_6h  → observations (quarterly/semi-annual/annual), vintage dates
  #   ttl_2h  → GeoFRED series/regional data
  #   ttl_1h  → observations (monthly), release dates
  #
  # ttl_overrides: %{
  #   ttl_24h: :timer.hours(48),
  #   ttl_12h: :timer.hours(6),
  #   ttl_6h:  :timer.hours(3),
  #   ttl_2h:  :timer.hours(1),
  #   ttl_1h:  :timer.minutes(30)
  # }

  # ── Rate Limiting ──────────────────────────────────────────────────────────
  # FRED enforces 120 requests per minute per API key.
  # On HTTP 429 the client retries automatically with exponential backoff:
  #
  #   attempt 1 → sleep base_delay × 1  (default 20 s)
  #   attempt 2 → sleep base_delay × 2  (default 40 s)
  #   attempt 3 → sleep base_delay × 3  (default 60 s)
  #   → give up, return {:error, %FredApiClient.HTTP.Error{code: 429}}
  #
  # The 20 s base ensures recovery within FRED's 60 s rate-limit window.
  # HTTP 503 (server overload) is also retried with a shorter 5 s base delay.
  rate_limit_max_retries: 3,
  rate_limit_base_delay_ms: 20_000

import_config "#{config_env()}.exs"
