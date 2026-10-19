import Config

config :translink_db, TranslinkDb.Repo,
  database: "translink_db",
  hostname: "localhost"

config :translink_db, ecto_repos: [TranslinkDb.Repo]
