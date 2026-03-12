# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-03-12
### Minor Refactor: 

* Refactor application start/0 to enable Cachex stats tracking by default

## [0.1.1] - 2026-03-12

### Added

#### Test Suite

* Comprehensive **ExUnit test suite** covering core modules:

  * `FredAPIClient.CacheTest`
  * `FredAPIClient.ClientTest`
  * `FredAPIClient.CategoriesTest`
  * `FredAPIClient.SeriesTest`
* **Bypass-based HTTP mocking** for all API calls to ensure tests run without external network access
* Tests verifying:

  * Cache hit/miss behaviour and TTL logic
  * Cache invalidation (`invalidate/1`, `invalidate_prefix/1`, `clear/0`)
  * Deterministic cache key generation (`build_key/3`)
  * HTTP client query building and parameter filtering
  * API error handling and structured `FredAPIClient.Error`
  * Retry behaviour and non-JSON error responses
* Added `test/test_helper.exs` to start ExUnit
* Total test coverage: **34 tests validating core behaviour**

---

## [0.1.0] - 2026-03-12

### Added

#### Core

* Full coverage of all **36 FRED API endpoints** across 7 modules:

  * `FredAPIClient.Categories` — 6 endpoints
  * `FredAPIClient.Releases`   — 9 endpoints
  * `FredAPIClient.Series`     — 10 endpoints
  * `FredAPIClient.Sources`    — 3 endpoints
  * `FredAPIClient.Tags`       — 3 endpoints
  * `FredAPIClient.Maps`       — 4 endpoints (GeoFRED)
  * `FredAPIClient.V2`         — 1 endpoint (bulk)
* Top-level `FredAPIClient` module with `defdelegate` shortcuts for all 36 endpoints
* Application config support via `config :fred_api_client, api_key: ...`
* Explicit per-call config support for multi-tenant / per-request API key usage
* `Req`-based HTTP client with per-request timeout and structured error handling
* `FredAPIClient.Error` exception struct with `code`, `status`, `message` fields

#### Caching (`FredAPIClient.Cache`)

* Cachex-backed in-process caching, started automatically by the OTP application
* **Frequency-aware TTLs** for `Series.get_observations/2`:

  * Daily / weekly (`d`, `w`, `bw` and weekly variants) → **not cached**
  * Monthly (`m`) → **1 h**
  * Quarterly / semi-annual / annual (`q`, `sa`, `a`) → **6 h**
  * Unspecified frequency → **not cached** (safe default)
* Static data cached aggressively: category tree and series metadata at **24 h**,
  release metadata at **12 h**, GeoFRED shapes at **24 h**, regional data at **2 h**
* Volatile endpoints intentionally not cached: `Series.search/2`,
  `Series.get_updates/2`, `Tags.get_series/2`, V2 bulk
* `Cache.invalidate/1` — delete a single key
* `Cache.invalidate_prefix/1` — delete all keys under a prefix (e.g. `"fred:categories:"`)
* `Cache.clear/0` — flush entire cache
* `Cache.stats/0` — hit rate, size, eviction counts via `Cachex.stats/1`
* `Cache.build_key/3` — deterministic, order-independent key builder (MD5 of sorted params)
* Global on/off via `config :fred_api_client, cache_enabled: false`
* Per-bucket TTL overrides via `config :fred_api_client, ttl_overrides: %{...}`
* Configurable cache process name via `config :fred_api_client, cache_name: :my_cache`

#### Rate Limiting

* Automatic **exponential backoff retry** on `HTTP 429 Too Many Requests`
* Default: 3 retries with 20 s base delay (20 s → 40 s → 60 s)
* `HTTP 503 Service Unavailable` also retried with a 5 s base delay
* Transport-level `:timeout` errors retried with a 3 s base delay
* Terminal errors (400, 404, 423, 500) returned immediately without retry
* Configurable via `rate_limit_max_retries` and `rate_limit_base_delay_ms`

#### Documentation & Quality

* ExDoc documentation with grouped modules (API, HTTP, Cache)
* Dialyzer typespecs on all public functions
* Credo strict-mode static analysis (`.credo.exs`)
* ExCoveralls test coverage with `lcov` reporter
* GitHub Actions CI: lint → test matrix (Elixir 1.15/1.16/1.17 × OTP 26/27)
  → Dialyzer → Hex publish on master push

### Fixed

* `Cache.invalidate_prefix/1`: replaced non-existent `Cachex.filter!/2` and
  `Cachex.Entry.key/1` with correct `Cachex.stream!(query)` +
  `Cachex.Query.build(output: :key)` pattern; keys are buffered before deletion
  to avoid mutating the ETS table during iteration
