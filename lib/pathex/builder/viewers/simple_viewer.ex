defmodule Pathex.Builder.SimpleViewer do

  @moduledoc """
  Simple viewer-builder for functions which apply func to value in the path

  With workaround to expand local macros
  to not create another function call
  """

  alias Pathex.Common
  import Pathex.Builder.Selector
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  defmacro wrap_ok(x) do
    quote do
      {:ok, unquote(x)}
    end
  end

  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> Macro.prewalk(&expand_local/1)
    #|> Macro.to_string()
    #|> IO.puts
    |> Pathex.Builder.Code.new_arg_pipe([@structure_variable, @function_variable])
  end

  defp reduce_into(path_items, acc) do
    path_items
    |> Enum.flat_map(& create_getter(&1, acc))
    |> Kernel.++(fallback())
    |> Common.to_case()
  end

  defp initial do
    quote do
      unquote(@function_variable).()
      |> unquote(__MODULE__).wrap_ok()
    end
  end

  defp expand_local({:and, _, _} = quoted), do: quoted # Some bug in Macro.expand
  defp expand_local(quoted) do
    env = %Macro.Env{requires: [__MODULE__]}
    Macro.expand(quoted, env)
  end

end
