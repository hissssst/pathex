defmodule Pathex.Builder.OptimizedSelector do

  @moduledoc """
  WIP Selector which tries to use one big case when possible
  """

  @behaviour Pathex.Builder.Selector
  import Pathex.Builder.Selector

  @type item :: {Pathex.struct_type(), atom() | binary() | non_neg_integer()}
  @type path :: [item()]
  @type tree :: {[path()], [item()], tree()} | :end

  def build(combination) do
    combination
    |> to_tree()
    |> build_from_tree()
    |> Pathex.Builder.Code.new_one_arg_pipe()
  end

  def build_from_tree(:end) do
    quote do
      (fn x -> {:ok, x} end).()
    end
  end
  def build_from_tree({matchables, [], _}) do
    complete_cases = Enum.flat_map(matchables, &path_to_getter/1)
    {:case, [], [[do: complete_cases ++ fallback()]]}
  end
  def build_from_tree({matchables, func_matches, tail}) do
    tail_tree = build_from_tree(tail)
    all_getters =
      [
        Enum.flat_map(matchables, &path_to_getter/1),
        Enum.flat_map(func_matches, & create_getter(&1, tail_tree)),
        fallback()
      ]
      |> Enum.concat()

    {:case, [], [[do: all_getters]]}
  end

  defp path_to_getter(path) do
    x = {:x, [], Elixir}
    {:ok, match} = match_from_path(path, x)
    quote do
      unquote(match) -> {:ok, unquote(x)}
    end
  end

  @doc """
  Creates tree like
  tree_item = {
    [matchable_paths],
    []

  }
  """
  def to_tree(combination) do
    combination
    |> Enum.reduce([], & [split(&1) | &2])
    |> Enum.reduce(nil, &tree_reduce/2)
  end

  defp tree_reduce({matchable, titems}, nil) do
    {Enum.map(matchable, &List.wrap/1), titems, :end}
  end
  defp tree_reduce({matchable, titems}, {tail_paths, _, _} = tail) do
    paths = Enum.flat_map(tail_paths, fn path ->
      Enum.map(matchable, & [&1 | path])
    end)
    {paths, titems, tail}
  end

  defp split(items) do
    Enum.split_with(items, &is_matchable?/1)
    |> put_elem(1, items)
  end

  defp is_matchable?({type, _}) when type in [:map, :list], do: true
  defp is_matchable?(_), do: false

end
