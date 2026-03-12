import Config

config :fred_api_client,
  # Your FRED API key — get one free at https://fred.stlouisfed.org/docs/api/api_key.html
  # Recommended: set via environment variable
  api_key: System.get_env("FRED_API_KEY"),
  base_url: "https://api.stlouisfed.org",
  file_type: "json",
  timeout: 30_000

import_config "#{config_env()}.exs"
