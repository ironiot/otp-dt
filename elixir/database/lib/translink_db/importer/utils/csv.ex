defmodule TranslinkDb.Importer.CSV do
  NimbleCSV.define(TranslinkDb.Importer.CSV.RowParser,
    separator: ",",
    trim: true,
    trim_bom: true
  )

  @type row :: %{
          file: String.t(),
          line: pos_integer(),
          fields: %{required(String.t()) => String.t()}
        }

  @spec stream(binary(), String.t()) :: Enumerable.t(row())
  def stream(content, name) do
    [header | rows] =
      TranslinkDb.Importer.CSV.RowParser.parse_string(content, skip_headers: false)

    rows
    |> Enum.reject(&blank_row?/1)
    |> Enum.with_index(2)
    |> Stream.map(fn {values, line_number} ->
      build_row(name, header, values, line_number)
    end)
  end

  defp blank_row?([]), do: true
  defp blank_row?([""]), do: true
  defp blank_row?(_row), do: false

  defp build_row(name, header, values, line_number) do
    if length(values) != length(header) do
      raise ArgumentError,
            "#{name}:#{line_number}: expected #{length(header)} fields, got #{length(values)}"
    end

    %{
      file: name,
      line: line_number,
      fields: header |> Enum.zip(values) |> Map.new()
    }
  end
end
