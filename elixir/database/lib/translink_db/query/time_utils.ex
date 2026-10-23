alias TranslinkDb.Query.Data

defmodule TranslinkDb.Query.TimeUtils do
  @spec split(DateTime.t()) :: {Date.t(), Data.seconds()}
  def split(dt) do
    date =
      dt
      |> DateTime.shift_zone!("Canada/Pacific")
      |> DateTime.to_date()

    seconds = dt.hour * 3600 + dt.minute * 60 + dt.second
    {date, seconds}
  end

  @spec join(Date.t(), Data.seconds()) :: DateTime.t()
  def join(date, seconds) do
    date
    |> DateTime.new!(~T[00:00:00], "Canada/Pacific")
    |> DateTime.add(seconds, :second)
  end

  @spec humanize(Data.seconds()) :: String.t()
  def humanize(seconds) when is_integer(seconds) do
    minutes = Integer.floor_div(seconds, 60)
    seconds = seconds - minutes * 60
    hours = Integer.floor_div(minutes, 60)
    minutes = minutes - hours * 60

    hours = if(hours == 0, do: "", else: "#{hours}h ")
    minutes = if(minutes == 0, do: "", else: "#{minutes}m ")
    seconds = if(seconds == 0, do: "", else: "#{seconds}s")

    String.trim("#{hours}#{minutes}#{seconds}")
  end

  @spec humanize(DateTime.t()) :: String.t()
  def humanize(datetime) do
    datetime |> DateTime.to_naive() |> NaiveDateTime.to_string()
  end
end
