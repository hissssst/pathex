defmodule Pathex.Builder.SimpleUpdater do
  # Updater-builder which generates function for simply updates value in the given path
  @moduledoc false

  alias Pathex.Builder.Setter
  alias Pathex.Common
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  @impl Pathex.Builder
  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> Setter.wrap_to_code([@structure_variable, @function_variable])
  end

  defp reduce_into(path_items, acc) do
    setters = Enum.flat_map(path_items, &Setter.create_updater(&1, acc))
    Common.to_case(setters ++ Setter.fallback())
  end

  defp initial do
    quote do
      unquote(@function_variable).()
      |> case do
        {:ok, value} -> value
        :error -> throw(:path_not_found)
      end
    end
  end
end
