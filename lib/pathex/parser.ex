defmodule Pathex.Parser do

  @type suggested_path :: [
    {Pathex.struct_type() | nil, Pathex.key_type() | nil, binary()}
  ]

  @spec parse(binary(), charlist()) :: suggested_path()
  def parse(string, 'naive') do
    string
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&detect_naive/1)
  end
  def parse(string, 'json') do
    string
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&detect_json/1)
  end
  def parse(string, 'map') do
    string
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.map(& {:map, nil, &1})
  end

  defp detect_json(str) do
    case Integer.parse(str) do
      {_, ""} -> {[:list, :map], [:integer, :binary], str}
      _ -> {:map, :binary, str}
    end
  end

  defp detect_naive("\"" <> str) do
    case String.trim_trailing(str, "\"") do
      ^str -> {nil, nil, "\"" <> str}
      other -> {nil, :binary, other}
    end
  end
  defp detect_naive(":" <> str) do
    {nil, :atom, str}
  end
  defp detect_naive(str) do
    case Integer.parse(str) do
      {_, ""} -> {nil, :integer, str}
      _ -> {nil, nil, str}
    end
  end

end
