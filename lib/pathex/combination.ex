defmodule Pathex.Combination do

  @type t :: [[{Pathex.struct_type(), atom() | binary() | non_neg_integer()}]]

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

end
