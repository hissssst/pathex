defmodule Pathex.Builder.MatchableViewer do

  @moduledoc """
  Viewer-builder which creates function which matches with one big case
  """

  alias Pathex.Common
  import Pathex.Builder.Selector
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  def build(combination) do
    getters =
      combination
      |> Pathex.Combination.to_paths()
      |> Enum.flat_map(& path_to_getter(&1))

    (getters ++ fallback())
    |> Common.to_case()
    |> Pathex.Builder.Code.new_arg_pipe([@structure_variable, @function_variable])
  end

  defp path_to_getter(path) do
    x = {:x, [], Elixir}
    {:ok, match} = match_from_path(path, x)
    quote do
      unquote(match) -> {:ok, unquote(x)}
    end
  end

end
