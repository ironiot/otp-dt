defmodule TranslinkDb.Schemas.StopTransfer do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "stop_transfer" do
    belongs_to(:from_stop, TranslinkDb.Schemas.Stop, primary_key: true)
    belongs_to(:to_stop, TranslinkDb.Schemas.Stop, primary_key: true)
    field(:seconds, :integer)
  end
end
