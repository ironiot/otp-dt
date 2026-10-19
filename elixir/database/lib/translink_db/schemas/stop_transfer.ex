defmodule TranslinkDb.Schemas.StopTransfer do
  use Ecto.Schema

  @primary_key false
  schema "stop_transfer" do
    belongs_to(:from_stop, TranslinkDb.Schemas.Stop,
      foreign_key: :from_stop_id,
      primary_key: true
    )

    belongs_to(:to_stop, TranslinkDb.Schemas.Stop, foreign_key: :to_stop_id, primary_key: true)

    field(:seconds, :integer)
  end
end
