defmodule TranslinkDb.Repo.Migrations.Realtime do
  use Ecto.Migration

  def change do
    create table(:rt_trip, primary_key: false) do
      add(:trip_id, references(:trip, type: :integer), primary_key: true)
      add(:date, :date, primary_key: true)
      add(:cancelled, :boolean, null: false, default: false)
      # Trip-level delay in seconds.
      add(:delay, :integer, null: false, default: 0)
    end

    create table(:rt_stop_time, primary_key: false) do
      add(:trip_id, references(:trip, type: :integer), primary_key: true)
      add(:stop_sequence, :integer, primary_key: true)
      add(:date, :date, primary_key: true)
      # Whether a bus will arrive at any particular stop is
      # 	!rt_trip.cancelled && !rt_stop_time.skipped
      # (i.e. a trip may be cancelled without updating individual stop times).
      add(:skipped, :boolean, null: false, default: false)
      # Stop-level delays in seconds.
      # The effective delay is
      # 	rt_stop_time.{arrival|departure}_delay ?? rt_trip.delay
      # (i.e., trip-level delay is a fallback, not an addition)
      add(:arrival_delay, :integer, null: true)
      add(:departure_delay, :integer, null: true)
    end

    execute(
      "ALTER TABLE rt_stop_time
        ADD CONSTRAINT fk_rt_trip
          FOREIGN KEY (trip_id, DATE)
          REFERENCES rt_trip (trip_id, date)
          ON DELETE CASCADE,
        ADD CONSTRAINT fk_stop_time
      		FOREIGN KEY (trip_id, stop_sequence)
           	REFERENCES stop_time (trip_id, stop_sequence)
           	ON DELETE CASCADE",
      # rollback
      "ALTER TABLE rt_stop_time
      	DROP CONSTRAINT fk_rt_trip,
      	DROP CONSTRAINT fk_stop_time"
    )
  end
end
