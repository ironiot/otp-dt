defmodule TranslinkDb.MixProject do
  use Mix.Project

  def project do
    [
      app: :translink_db,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl],
      mod: {TranslinkDb.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.0"},
      {:nimble_csv, "~> 1.2"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.7.0"},
      {:timescale, "~> 0.1.0"}
    ]
  end
end
