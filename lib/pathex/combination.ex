defmodule Pathex.Combination do

  @type t :: [[{Pathex.struct_type(), atom() | binary() | non_neg_integer()}]]

  defguardp is_suggestion(x) when is_list(x) or is_atom(x)

  @spec from_suggested_path(Pathex.Parser.suggested_path()) :: t()
  def from_suggested_path(path) do
    Enum.map(path, &detect/1)
  end

  @spec from_path(Pathex.path()) :: t()
  def from_path(path) do
    Enum.map(path, &List.wrap/1)
  end

  @spec to_paths(t()) :: [Pathex.path()]
  def to_paths([]), do: []
  def to_paths([last]), do: Enum.map(last, &List.wrap/1)
  def to_paths([heads | tail]) do
    Enum.flat_map(heads, fn head ->
      tail
      |> to_paths()
      |> Enum.map(& [head | &1])
    end)
  end

  defp detect(
    {stype, ktype, key}
  ) when is_binary(key) and is_suggestion(stype) and is_suggestion(ktype) do
    {stypes, ktypes} = detect_from_key(key)
    stypes = join(stype, stypes)
    ktypes = join(ktype, ktypes)
    Enum.flat_map(stypes, fn stype ->
      Enum.flat_map(ktypes, fn ktype ->
        cast(ktype, stype, key)
      end)
    end)
  end

  defp detect_from_key(key) do
    case Integer.parse(key) do
      {_, ""} ->
        {[:map, :keyword, :list, :tuple], [:integer, :atom, :binary]}

      _ ->
        {[:map, :keyword], [:atom, :binary]}
    end
  end

  defp join(nil, detected), do: detected
  defp join(suggested, detected) when is_list(suggested) do
    Enum.filter(suggested, & &1 in detected)
  end
  defp join(suggested, detected) when is_atom(suggested) do
    if(suggested in detected, do: [suggested], else: detected)
  end

  defp cast(:integer, stype, key) when stype in [:list, :map, :tuple] do
    [{stype, String.to_integer(key)}]
  end
  defp cast(:atom, stype, key) when stype in [:keyword, :map] do
    [{stype, String.to_atom(key)}]
  end
  defp cast(:binary, :map, key), do: [map: key]
  defp cast(_, _, _), do: []

end
