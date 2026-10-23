import Config

config :translink_db, TranslinkDb.Repo,
  database: "translink_db",
  hostname: "localhost",
  log: false,
  timeout: 600_000,
  pool_size: 16

config :translink_db, ecto_repos: [TranslinkDb.Repo]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ex_fuzzywuzzy,
  similarity_fn: &ExFuzzywuzzy.Similarity.Levenshtein.calculate/2,
  case_sensitive: false,
  precision: 0
