import Config

# Runtime config — loaded after compilation.
# Use this for secrets in production.
if config_env() == :prod do
  config :fred_api_client,
    api_key: System.fetch_env!("FRED_API_KEY")
end
