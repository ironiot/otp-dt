defmodule TranslinkDb.Importer.Batch do
  alias TranslinkDb.Repo

  @batch_size 5_000

  @spec insert_in_batches(module(), Enumerable.t()) :: :ok
  def insert_in_batches(schema, rows) do
    rows
    |> Stream.chunk_every(@batch_size)
    |> Enum.each(fn batch -> Repo.insert_all(schema, batch) end)
  end
end
