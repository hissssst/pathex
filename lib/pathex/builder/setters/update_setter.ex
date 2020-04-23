defmodule Pathex.Builder.UpdateSetter do

  import Pathex.Builder.Setter
  @behaviour Pathex.Builder.Setter

  @first_arg {:first_arg, [], Elixir}
  @initial {:function_to_call, [], Elixir}

  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> wrap_to_code(@first_arg, @initial)
  end

  defp reduce_into(path_items, acc) do
    setters = Enum.flat_map(path_items, & create_setter(&1, acc))
    {:case, [], [[do: setters ++ fallback()]]}
  end

  defp initial do
    quote do
      unquote(@initial).()
    end
  end

end
