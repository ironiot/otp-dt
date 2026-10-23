defmodule TranslinkDb.Importer.Parser do
  @type row :: TranslinkDb.Importer.CSV.row()
  @type error :: String.t()

  @spec string(row(), String.t()) :: {:ok, String.t()} | {:error, error()}
  def string(row, field) do
    with {:ok, value} <- fetch(row, field) do
      {:ok, String.trim(value)}
    end
  end

  @spec integer(row(), String.t()) :: {:ok, integer()} | {:error, error()}
  def integer(row, field) do
    parse(row, field, &parse_integer/1)
  end

  @spec optional_integer(row(), String.t()) :: {:ok, integer() | nil} | {:error, error()}
  def optional_integer(row, field) do
    parse(row, field, &parse_optional_integer/1)
  end

  @spec float(row(), String.t()) :: {:ok, float()} | {:error, error()}
  def float(row, field) do
    parse(row, field, &parse_float/1)
  end

  @spec date(row(), String.t()) :: {:ok, Date.t()} | {:error, error()}
  def date(row, field) do
    parse(row, field, &parse_date/1)
  end

  @spec time(row(), String.t()) :: {:ok, non_neg_integer()} | {:error, error()}
  def time(row, field) do
    parse(row, field, &parse_time/1)
  end

  @spec stop_flag(row(), String.t()) :: {:ok, boolean()} | {:error, error()}
  def stop_flag(row, field) do
    parse(row, field, &parse_stop_flag/1)
  end

  defp parse(row, field, parser) do
    with {:ok, value} <- fetch(row, field) do
      try do
        {:ok, parser.(value)}
      rescue
        _ ->
          {:error, "#{row.file}:#{row.line}: invalid #{field} #{inspect(value)}"}
      end
    end
  end

  defp fetch(row, field) do
    case Map.fetch(row.fields, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "#{row.file}:#{row.line}: missing field #{inspect(field)}"}
    end
  end

  defp parse_integer(value) do
    value
    |> String.trim()
    |> String.to_integer()
  end

  defp parse_optional_integer(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> String.to_integer(trimmed)
    end
  end

  defp parse_float(value) do
    case Float.parse(String.trim(value)) do
      {float, ""} -> float
      _ -> raise ArgumentError, "expected a number"
    end
  end

  defp parse_date(value) do
    case String.trim(value) do
      <<year::binary-size(4), month::binary-size(2), day::binary-size(2)>> ->
        Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

      _ ->
        raise ArgumentError, "expected YYYYMMDD"
    end
  end

  defp parse_time(value) do
    value = String.trim(value)

    case String.split(value, ":") do
      [hours, minutes, seconds] ->
        hours = String.to_integer(hours)
        minutes = String.to_integer(minutes)
        seconds = String.to_integer(seconds)

        if hours >= 0 and minutes in 0..59 and seconds in 0..59 do
          hours * 3600 + minutes * 60 + seconds
        else
          raise ArgumentError, "expected H:MM:SS"
        end

      _ ->
        raise ArgumentError, "expected H:MM:SS"
    end
  end

  defp parse_stop_flag(value) do
    case String.trim(value) do
      "0" -> true
      "1" -> false
      _ -> raise ArgumentError, "expected 0 or 1"
    end
  end
end
