defmodule Pathex.Builder.SimpleSelector do

  @behaviour Pathex.Builder.Selector
  import Pathex.Builder.Selector

  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> Pathex.Builder.Code.new_one_arg_pipe()
  end

  defp reduce_into(path_items, acc) do
    getters = Enum.flat_map(path_items, & create_getter(&1, acc))
    {:case, [], [[do: getters ++ fallback()]]}
  end

  defp initial() do
    quote do
      (fn x -> {:ok, x} end).()
    end
  end

end
