defmodule TranslinkDb.Query.Name do
  def normalize(name) do
    [
      ~r/[^\w\s]/,
      ~r/^(east|south|north|west)bound/,
      ~r/unload(ing)? only$/,
      ~r/flag$/,
      ~r/(platform|bay) \d+$/
    ]
    |> Enum.reduce(String.downcase(name), &Regex.replace(&1, &2, " "))
    |> String.split(" ")
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join(" ")
  end
end
