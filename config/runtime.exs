import Config

# =============================================================================
# FredAPIClient — Runtime Configuration
#
# This file is evaluated at runtime (after compilation) by Mix and releases.
# Put all secrets here. Never put secrets in config/config.exs or other
# compile-time config files that may end up in version control.
#
# See: https://hexdocs.pm/phoenix/releases.html#runtime-configuration
# =============================================================================

if config_env() == :prod do
  # ── Required ───────────────────────────────────────────────────────────────
  # Raises at boot if FRED_API_KEY is not set — fail fast rather than getting
  # mysterious 403 errors at runtime.
  config :fred_api_client,
    api_key: System.fetch_env!("FRED_API_KEY"),

    # ── HTTP ─────────────────────────────────────────────────────────────────
    # Increase timeout for production where the FRED API may be under load.
    timeout: 30_000,

    # ── Caching ──────────────────────────────────────────────────────────────
    cache_enabled: true,

    # Uncomment and tune if you need different TTLs in production:
    # ttl_overrides: %{
    #   ttl_1h: :timer.minutes(45)
    # },

    # ── Rate Limiting ─────────────────────────────────────────────────────────
    # Production defaults — 3 retries with 20 s base recovers within
    # FRED's 60 s rate-limit window without blocking for too long.
    rate_limit_max_retries: 3,
    rate_limit_base_delay_ms: 20_000
end
