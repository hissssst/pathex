defmodule Pathex.Builder.Composition.Or do
  # This builder builds composition for `|||` operator
  @moduledoc false

  @behaviour Pathex.Builder.Composition
  alias Pathex.Builder.Code
  alias Pathex.Builder.Composition

  @impl Pathex.Builder.Composition
  def build(items) do
    [
      delete: build_delete(items),
      force_update: build_force_update(items),
      update: build_update(items),
      inspect: Composition.build_inspect(items, :|||),
      view: build_view(items)
    ]
  end

  defp build_delete([head | tail]) do
    structure = {:x, [], Elixir}
    func = {:func, [], Elixir}
    first_case = to_delete(head, structure, func)

    [first_case | Enum.map(tail, &to_delete(&1, structure, func))]
    |> to_with()
    |> Code.new([structure, func])
  end

  defp build_view([head | tail]) do
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    first_case = to_view(head, structure, func)

    [first_case | Enum.map(tail, &to_view(&1, structure, func))]
    |> to_with()
    |> Code.new([structure, func])
  end

  defp build_update([head | tail]) do
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    first_case = to_update(head, structure, func)

    [first_case | Enum.map(tail, &to_update(&1, structure, func))]
    |> to_with()
    |> Code.new([structure, func])
  end

  defp build_force_update([head | tail]) do
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    default = {:default, [], Elixir}
    first_case = to_force_update(head, structure, func, default)

    [first_case | Enum.map(tail, &to_force_update(&1, structure, func, default))]
    |> to_with()
    |> Code.new([structure, func, default])
  end

  # You can find almost the same code in `Pathex.Builder.Composition.And`
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

  defp to_delete(item, structure, func) do
    quote do
      :error <- unquote(item).(:delete, {unquote(structure), unquote(func)})
    end
  end

  defp to_force_update(item, structure, func, default) do
    quote do
      :error <-
        unquote(item).(:force_update, {unquote(structure), unquote(func), unquote(default)})
    end
  end
end
