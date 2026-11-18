defmodule TranslinkDb.Util.Batch do
  alias TranslinkDb.Repo

  @batch_size 5_000

  @spec insert_all(module(), Enumerable.t()) :: :ok
  def insert_all(schema, rows, opts \\ []) do
    rows
    |> Stream.chunk_every(@batch_size)
    |> Enum.each(&Repo.insert_all(schema, &1, opts))
  end
end
