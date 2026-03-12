import Config

# =============================================================================
# FredAPIClient — Test Configuration
#
# Tests use Bypass to spin up a local HTTP server — no real FRED API calls.
# =============================================================================

config :fred_api_client,
  # Dummy key — Bypass intercepts all requests before they hit the network
  api_key: "test_api_key",

  # Fast timeout so test failures surface immediately
  timeout: 5_000,

  # Cache DISABLED in tests so each test gets a fresh HTTP call via Bypass.
  # Individual test cases that specifically test caching behaviour
  # (cache_test.exs) re-enable it by calling Cache.clear() in setup.
  cache_enabled: false,

  # Retry configuration: very short delays so retry tests run in milliseconds.
  # Each test that needs specific retry counts overrides these via
  # Application.put_env/3 in its setup block.
  rate_limit_max_retries: 2,
  rate_limit_base_delay_ms: 10
