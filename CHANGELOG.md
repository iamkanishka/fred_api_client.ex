# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-10

### Added
- Initial release
- Full coverage of all 36 FRED API endpoints across 7 groups:
  - `FredApiClient.Categories` — 6 endpoints
  - `FredApiClient.Releases` — 9 endpoints
  - `FredApiClient.Series` — 10 endpoints
  - `FredApiClient.Sources` — 3 endpoints
  - `FredApiClient.Tags` — 3 endpoints
  - `FredApiClient.Maps` (GeoFRED) — 4 endpoints
  - `FredApiClient.V2` (Bulk) — 1 endpoint
- Top-level `FredApiClient` module with delegator functions for all 36 endpoints
- Application config support via `config :fred_api_client, api_key: ...`
- Explicit per-call config support for multi-tenant usage
- `Req`-based HTTP client with timeout and structured error handling
- `FredApiClient.Error` exception struct with `code`, `status`, `message`
- ExDoc documentation with grouped modules
- Dialyzer typespecs on all public functions
- Credo static analysis configuration
- ExCoveralls test coverage
- GitHub Actions CI with Elixir 1.15/1.16/1.17 matrix + Dialyzer + Hex publish
