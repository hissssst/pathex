defmodule Pathex.Builder.SimpleViewer do
  @moduledoc false
  # Simple viewer-builder for functions which apply func to value in the path

  # With workaround to expand local macros
  # to not create another function call

  alias Pathex.Builder.Viewer
  alias Pathex.Common
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  @impl Pathex.Builder
  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> Macro.prewalk(&Viewer.expand_local/1)
    |> Pathex.Builder.Code.new_arg_pipe([@structure_variable, @function_variable])
  end

  defp reduce_into(path_items, acc) do
    path_items
    |> Enum.flat_map(&Viewer.create_viewer(&1, acc))
    |> Kernel.++(Viewer.fallback())
    |> Common.to_case()
  end

  defp initial do
    quote do
      unquote(@function_variable).()
    end
  end
end
