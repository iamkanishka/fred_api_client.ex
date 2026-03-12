import Config

# =============================================================================
# FredApiClient — Development Configuration
# =============================================================================

config :fred_api_client,
  # Shorter timeout in dev so failures surface quickly
  timeout: 15_000,

  # Cache is on in dev — mirrors production behaviour.
  # Set to false here if you prefer live API responses while developing.
  cache_enabled: true,
  cache_stats: true,

  # Lower TTLs in dev so you see fresh data without restarting.
  # Remove or adjust these to match production TTLs when profiling.
  ttl_overrides: %{
    ttl_24h: :timer.minutes(10),
    ttl_12h: :timer.minutes(5),
    ttl_6h: :timer.minutes(3),
    ttl_2h: :timer.minutes(2),
    ttl_1h: :timer.minutes(1)
  },

  # Fewer retries in dev — fail fast so you notice 429s immediately
  rate_limit_max_retries: 1,
  rate_limit_base_delay_ms: 5_000
