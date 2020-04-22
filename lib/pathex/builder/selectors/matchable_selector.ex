defmodule Pathex.Builder.MatchableSelector do

  @behaviour Pathex.Builder.Selector
  import Pathex.Builder.Selector

  def build(combination) do
    getters =
      combination
      |> Pathex.Combination.to_paths()
      |> Enum.flat_map(&path_to_getter/1)

    {:case, [], [[do: getters ++ fallback()]]}
    |> Pathex.Builder.Code.new_one_arg_pipe()
  end

  defp path_to_getter(path) do
    x = {:x, [], Elixir}
    {:ok, match} = match_from_path(path, x)
    quote do
      unquote(match) -> {:ok, unquote(x)}
    end
  end

end
