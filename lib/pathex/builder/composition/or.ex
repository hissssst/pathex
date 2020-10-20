defmodule Pathex.Builder.Composition.Or do

  @moduledoc """
  This builder builds composition for `|||` operator
  """

  @behaviour Pathex.Builder.Composition
  alias Pathex.Builder.Code

  def build(items) do
    [
      view:         build_view(items),
      update:       build_update(items),
      force_update: build_force_update(items)
    ]
  end

  defp build_view([head | tail]) do
    structure  = {:input_struct, [], Elixir}
    func       = {:func, [], Elixir}
    first_case = to_view(head, structure, func)

    [first_case | Enum.map(tail, & to_view(&1, structure, func))]
    |> to_with()
    |> Code.new([structure, func])
  end

  defp build_update([head | tail]) do
    structure  = {:input_struct, [], Elixir}
    func       = {:func, [], Elixir}
    first_case = to_update(head, structure, func)

    [first_case | Enum.map(tail, & to_update(&1, structure, func))]
    |> to_with()
    |> Code.new([structure, func])
  end

  defp build_force_update([head | tail]) do
    structure  = {:input_struct, [], Elixir}
    func       = {:func, [], Elixir}
    default    = {:default, [], Elixir}
    first_case = to_force_update(head, structure, func, default)

    [first_case | Enum.map(tail, & to_force_update(&1, structure, func, default))]
    |> to_with()
    |> Code.new([structure, func, default])
  end

  # You can find the same code in `Pathex.Builder.Composition.And`
  # But I don't mind some duplication
  defp to_with(cases) do
    quote do
      with unquote_splicing(cases) do
        :error
      end
    end
  end

  defp to_view(item, structure, func) do
    quote do
      :error <- unquote(item).(:view, {unquote(structure), unquote(func)})
    end
  end

  defp to_update(item, structure, func) do
    quote do
      :error <- unquote(item).(:update, {unquote(structure), unquote(func)})
    end
  end

  defp to_force_update(item, structure, func, default) do
    quote do
      :error <- unquote(item).(:force_update, {unquote(structure), unquote(func), unquote(default)})
    end
  end

end
