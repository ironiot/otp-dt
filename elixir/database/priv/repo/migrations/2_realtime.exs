defmodule TranslinkDb.Repo.Migrations.Realtime do
  use Ecto.Migration

  def change do
    create table(:rt_trip, primary_key: false) do
      add(:trip_id, references(:trip, type: :integer), primary_key: true)
      add(:date, :date, primary_key: true)
      add(:cancelled, :boolean, null: true)
    end

    create table(:rt_stop_time, primary_key: false) do
      add(:trip_id, references(:trip, type: :integer), primary_key: true)
      add(:stop_sequence, :integer, primary_key: true)
      add(:date, :date, primary_key: true)
      # Whether a bus will arrive at any particular stop is
      # 	!rt_trip.cancelled && !rt_stop_time.skipped
      # (i.e. a trip may be cancelled without updating individual stop times).
      add(:skipped, :boolean, null: true)
      # Delay in seconds, negative means early
      add(:arrival_delay, :integer, null: true)
      add(:departure_delay, :integer, null: true)
    end
  end
end
