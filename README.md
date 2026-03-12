# FredApiClient

[![Hex.pm](https://img.shields.io/hexpm/v/fred_api_client.svg)](https://hex.pm/packages/fred_api_client)
[![CI](https://github.com/iamkanishka/fred_api_client/actions/workflows/ci.yml/badge.svg)](https://github.com/iamkanishka/fred_api_client/actions)
[![Coverage](https://codecov.io/gh/iamkanishka/fred_api_client/branch/master/graph/badge.svg)](https://codecov.io/gh/iamkanishka/fred_api_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)

A fully-typed Elixir client for the [Federal Reserve Economic Data (FRED®) API](https://fred.stlouisfed.org/docs/api/fred/).

Covers all **36 endpoints** across 7 groups — Categories, Releases, Series, Sources, Tags,
GeoFRED Maps, and bulk API v2 — with **built-in Cachex caching**, **frequency-aware TTLs**,
and **automatic retry on rate-limit errors**.

---

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
  - [Minimal](#minimal)
  - [Full reference](#full-reference)
  - [Runtime secrets (production)](#runtime-secrets-production)
- [Quick Start](#quick-start)
- [Caching](#caching)
  - [TTL strategy](#ttl-strategy)
  - [Manual cache control](#manual-cache-control)
  - [Disabling the cache](#disabling-the-cache)
  - [Overriding TTLs](#overriding-ttls)
- [Rate Limiting](#rate-limiting)
- [Error Handling](#error-handling)
- [Multi-tenant / Explicit Config](#multi-tenant--explicit-config)
- [API Coverage](#api-coverage)
- [License](#license)

---

## Installation

Add `fred_api_client` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:fred_api_client, "~> 0.1"}
  ]
end
```

Then fetch:

```bash
mix deps.get
```

Get a free FRED API key at <https://fred.stlouisfed.org/docs/api/api_key.html>.

---

## Configuration

### Minimal

```elixir
# config/runtime.exs  ← recommended: keeps secrets out of compiled code
import Config

config :fred_api_client,
  api_key: System.fetch_env!("FRED_API_KEY")
```

### Full reference

```elixir
# config/config.exs
import Config

config :fred_api_client,
  # ── Required ─────────────────────────────────────────────────────
  api_key:   System.get_env("FRED_API_KEY"),

  # ── HTTP ─────────────────────────────────────────────────────────
  base_url:  "https://api.stlouisfed.org",  # default
  file_type: "json",                         # default — "json" | "xml"
  timeout:   30_000,                         # default — milliseconds

  # ── Caching (Cachex) ─────────────────────────────────────────────
  cache_enabled: true,           # default — set false to disable globally
  cache_name:    :fred_api_cache, # default — Cachex process name

  # Optional: override individual TTL buckets (values in milliseconds).
  # Only set the buckets you want to change — others keep their defaults.
  ttl_overrides: %{
    ttl_24h: :timer.hours(48),      # categories, series metadata, sources, shapes
    ttl_12h: :timer.hours(6),       # release metadata, tags
    ttl_6h:  :timer.hours(3),       # quarterly/annual observations, vintage dates
    ttl_2h:  :timer.hours(1),       # GeoFRED series/regional data
    ttl_1h:  :timer.minutes(30)     # monthly observations, release dates
  },

  # ── Rate Limiting ────────────────────────────────────────────────
  # FRED enforces 120 requests/minute per API key.
  # On HTTP 429 the client retries with exponential backoff:
  #   attempt 1 → wait base_delay × 1  (default 20 s)
  #   attempt 2 → wait base_delay × 2  (default 40 s)
  #   attempt 3 → wait base_delay × 3  (default 60 s) → give up
  rate_limit_max_retries:    3,       # default
  rate_limit_base_delay_ms:  20_000   # default
```

### Runtime secrets (production)

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :fred_api_client,
    api_key: System.fetch_env!("FRED_API_KEY")
end
```

---

## Quick Start

```elixir
# GDP quarterly observations — automatically cached for 6 h
{:ok, data} = FredApiClient.get_series_observations(%{
  series_id:         "GDP",
  observation_start: "2010-01-01",
  units:             "pc1",
  frequency:         "q"
})

IO.inspect(data["observations"])
# [%{"date" => "2010-01-01", "value" => "3.7"}, ...]

# Search for series (not cached — free-text results vary)
{:ok, results} = FredApiClient.search_series(%{
  search_text: "unemployment rate",
  limit:       5,
  order_by:    "popularity",
  sort_order:  "desc"
})

# All releases (cached 12 h)
{:ok, releases} = FredApiClient.get_releases(%{limit: 10})

# Category tree (cached 24 h)
{:ok, children} = FredApiClient.get_category_children(%{category_id: 0})

# GeoFRED regional data (cached 2 h)
{:ok, geo} = FredApiClient.get_regional_data(%{
  series_group: "882",
  region_type:  "state",
  date:         "2023-01-01",
  season:       "NSA",
  units:        "Dollars"
})
```

---

## Caching

Caching is **enabled by default** via [Cachex](https://hex.pm/packages/cachex). The Cachex
process is started automatically by the library's OTP application — no setup required.

### TTL strategy

TTLs are tuned to match FRED's actual publication cadence, not arbitrary round numbers:

| Data type | TTL | Reason |
|---|---|---|
| Category tree | 24 h | Essentially static — structure never changes |
| Series metadata | 24 h | Title, units, frequency never change |
| Series categories / release / tags | 24 h | Static mappings |
| Release metadata, series, tables, tags | 12 h | Rarely changes |
| Release sources | 24 h | Source organisations never change |
| Tags vocabulary | 12 h | New tags are rare |
| GeoFRED shapes / series group | 24 h | Static geographic metadata |
| Observations — quarterly / semi-annual / annual | 6 h | Published ~4× per year |
| Series vintage dates | 6 h | List grows slowly |
| GeoFRED series / regional data | 2 h | Updated on release schedule |
| Observations — monthly | 1 h | Published monthly |
| Release dates | 1 h | Changes on publish schedule |

**Not cached (volatile):**

| Endpoint | Reason |
|---|---|
| `Series.search/2` | Free-text — results differ per query |
| `Series.get_updates/2` | Volatile by design |
| `Series.get_search_tags/2` / `get_search_related_tags/2` | Query-dependent |
| `Tags.get_series/2` | Tag combination results vary |
| `V2.get_release_observations/2` | Large bulk payload |
| Observations — `d` / `w` / `bw` and all weekly variants | Updated too frequently |
| Observations — unspecified frequency | Cannot determine volatility safely |

### Manual cache control

The `FredApiClient.Cache` module exposes the full cache API:

```elixir
alias FredApiClient.Cache

# Invalidate a single key
Cache.invalidate("fred:series:get_series:abc123")

# Invalidate an entire group by prefix
{:ok, deleted_count} = Cache.invalidate_prefix("fred:categories:")
{:ok, deleted_count} = Cache.invalidate_prefix("fred:series:")

# Clear everything
Cache.clear()

# Inspect cache size and status
{:ok, stats} = Cache.stats()
# %{hits: 142, misses: 38, evictions: 0, ...}

# Manually build a key (useful for targeted invalidation)
key = Cache.build_key("series", "get_series", %{series_id: "GDP"})
Cache.invalidate(key)
```

### Disabling the cache

**Globally** — in `config/test.exs` or wherever you don't want caching:

```elixir
config :fred_api_client, cache_enabled: false
```

**Per-config call** — pass an explicit config with `cache_enabled: false` (see
[Multi-tenant / Explicit Config](#multi-tenant--explicit-config) below):

```elixir
config = %{api_key: "...", cache_enabled: false}
FredApiClient.get_series_observations(%{series_id: "GDP"}, config)
```

### Overriding TTLs

You can tune any TTL bucket without changing code:

```elixir
# config/config.exs
config :fred_api_client,
  ttl_overrides: %{
    ttl_1h:  :timer.minutes(30),   # halve the monthly-observations TTL
    ttl_24h: :timer.hours(48)      # cache static data for 2 days instead of 1
  }
```

Only the keys you specify are overridden — others stay at their defaults.

---

## Rate Limiting

The FRED API enforces **120 requests per minute** per API key. Exceeding this returns
`HTTP 429 Too Many Requests`.

The client handles `429` automatically with **exponential backoff**. The default of
3 retries with a 20 s base delay recovers safely within the 60 s rate-limit window:

| Attempt | Wait |
|---|---|
| 1st retry | 20 s |
| 2nd retry | 40 s |
| 3rd retry | 60 s |
| Give up | `{:error, %FredApiClient.HTTP.Error{code: 429}}` |

`503 Service Unavailable` is also retried automatically (5 s base delay, shorter backoff).

**Practical tip:** For bulk data collection, enable caching (default) and batch your calls.
A warm cache means most calls never hit the network, making the rate limit a non-issue in
practice.

To tune retry behaviour:

```elixir
config :fred_api_client,
  rate_limit_max_retries:   5,       # more retries for unreliable networks
  rate_limit_base_delay_ms: 10_000   # shorter delay if you have burst headroom
```

---

## Error Handling

All functions return `{:ok, map()}` or `{:error, %FredApiClient.HTTP.Error{}}`:

```elixir
case FredApiClient.get_series_observations(%{series_id: "INVALID"}) do
  {:ok, data} ->
    IO.inspect(data["observations"])

  {:error, %FredApiClient.HTTP.Error{code: 400, message: message}} ->
    Logger.warning("Bad request: #{message}")

  {:error, %FredApiClient.HTTP.Error{code: 429, message: message}} ->
    Logger.error("Rate limit hit after all retries: #{message}")

  {:error, %FredApiClient.HTTP.Error{code: 408}} ->
    Logger.error("Request timed out")
end
```

`FredApiClient.HTTP.Error` fields:

| Field | Type | Description |
|---|---|---|
| `code` | `integer` | FRED API error code, or HTTP status code |
| `status` | `integer \| nil` | HTTP status (`nil` for timeout / network errors) |
| `message` | `string` | Human-readable description |

---

## Multi-tenant / Explicit Config

Pass a config map as the second argument to use a different API key per call.
This bypasses application config entirely:

```elixir
config = %{
  api_key:                  "tenant_specific_key",
  timeout:                  10_000,
  cache_enabled:            true,
  rate_limit_max_retries:   2,
  rate_limit_base_delay_ms: 5_000
}

FredApiClient.get_series_observations(%{series_id: "GDP"}, config)
```

All API modules also accept an explicit config directly:

```elixir
FredApiClient.API.Series.get_observations(%{series_id: "GDP"}, config)
FredApiClient.API.Categories.get_category(%{category_id: 125}, config)
```

---

## API Coverage

All 36 endpoints, grouped by module:

| Module | Function | Endpoint | Cached |
|---|---|---|---|
| `FredApiClient.API.Categories` | `get_category/2` | `GET /fred/category` | ✅ 24 h |
| | `get_children/2` | `GET /fred/category/children` | ✅ 24 h |
| | `get_related/2` | `GET /fred/category/related` | ✅ 24 h |
| | `get_series/2` | `GET /fred/category/series` | ✅ 24 h |
| | `get_tags/2` | `GET /fred/category/tags` | ✅ 24 h |
| | `get_related_tags/2` | `GET /fred/category/related_tags` | ✅ 24 h |
| `FredApiClient.API.Releases` | `get_releases/2` | `GET /fred/releases` | ✅ 12 h |
| | `get_all_release_dates/2` | `GET /fred/releases/dates` | ✅ 1 h |
| | `get_release/2` | `GET /fred/release` | ✅ 12 h |
| | `get_release_dates/2` | `GET /fred/release/dates` | ✅ 1 h |
| | `get_release_series/2` | `GET /fred/release/series` | ✅ 12 h |
| | `get_release_sources/2` | `GET /fred/release/sources` | ✅ 24 h |
| | `get_release_tags/2` | `GET /fred/release/tags` | ✅ 12 h |
| | `get_release_related_tags/2` | `GET /fred/release/related_tags` | ✅ 12 h |
| | `get_release_tables/2` | `GET /fred/release/tables` | ✅ 12 h |
| `FredApiClient.API.Series` | `get_series/2` | `GET /fred/series` | ✅ 24 h |
| | `get_categories/2` | `GET /fred/series/categories` | ✅ 24 h |
| | `get_observations/2` | `GET /fred/series/observations` | ⚠️ by freq |
| | `get_release/2` | `GET /fred/series/release` | ✅ 24 h |
| | `search/2` | `GET /fred/series/search` | ❌ |
| | `get_search_tags/2` | `GET /fred/series/search/tags` | ❌ |
| | `get_search_related_tags/2` | `GET /fred/series/search/related_tags` | ❌ |
| | `get_tags/2` | `GET /fred/series/tags` | ✅ 24 h |
| | `get_updates/2` | `GET /fred/series/updates` | ❌ |
| | `get_vintage_dates/2` | `GET /fred/series/vintagedates` | ✅ 6 h |
| `FredApiClient.API.Sources` | `get_sources/2` | `GET /fred/sources` | ✅ 24 h |
| | `get_source/2` | `GET /fred/source` | ✅ 24 h |
| | `get_source_releases/2` | `GET /fred/source/releases` | ✅ 24 h |
| `FredApiClient.API.Tags` | `get_tags/2` | `GET /fred/tags` | ✅ 12 h |
| | `get_related_tags/2` | `GET /fred/related_tags` | ✅ 12 h |
| | `get_series/2` | `GET /fred/tags/series` | ❌ |
| `FredApiClient.API.Maps` | `get_shapes/2` | `GET /geofred/shapes/file` | ✅ 24 h |
| | `get_series_group/2` | `GET /geofred/series/group` | ✅ 24 h |
| | `get_series_data/2` | `GET /geofred/series/data` | ✅ 2 h |
| | `get_regional_data/2` | `GET /geofred/regional/data` | ✅ 2 h |
| `FredApiClient.API.V2` | `get_release_observations/2` | `GET /fred/v2/release/observations` | ❌ |

⚠️ = frequency-aware: `m` → 1 h, `q`/`sa`/`a` → 6 h, `d`/`w`/`bw` → not cached

---

## License

MIT — see [LICENSE.txt](LICENSE.txt).