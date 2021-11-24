defmodule Pathex.Builder.Composition.And do
  @moduledoc """
  This builder builds composition for `&&&` operator
  """

  @behaviour Pathex.Builder.Composition
  alias Pathex.Builder.Code

  def build(items) do
    [
      view: build_view(items),
      update: build_update(items),
      force_update: build_force_update(items)
    ]
  end

  defp build_view([head | tail]) do
    ret = {:x, [], Elixir}
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    first_case = to_view(head, ret, structure, func)

    [first_case | Enum.map(tail, &to_view(&1, quote(do: ^unquote(ret)), structure, func))]
    |> to_with(ret)
    |> Code.new([structure, func])
  end

  defp build_update([head | tail]) do
    ret = {:x, [], Elixir}
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    first_case = to_update(head, ret, structure, func)

    [first_case | Enum.map(tail, &to_update(&1, ret, ret, func))]
    |> to_with(ret)
    |> Code.new([structure, func])
  end

  defp build_force_update([head | tail]) do
    ret = {:x, [], Elixir}
    structure = {:input_struct, [], Elixir}
    func = {:func, [], Elixir}
    default = {:default, [], Elixir}
    first_case = to_force_update(head, ret, structure, func, default)

    [first_case | Enum.map(tail, &to_force_update(&1, ret, ret, func, default))]
    |> to_with(ret)
    |> Code.new([structure, func, default])
  end

  defp to_with(cases, ret) do
    quote do
      with unquote_splicing(cases) do
        {:ok, unquote(ret)}
      else
        _ -> :error
      end
    end
  end

  defp to_view(item, ret, structure, func) do
    quote do
      {:ok, unquote(ret)} <- unquote(item).(:view, {unquote(structure), unquote(func)})
    end
  end

  defp to_update(item, ret, structure, func) do
    quote do
      {:ok, unquote(ret)} <- unquote(item).(:update, {unquote(structure), unquote(func)})
    end
  end

  defp to_force_update(item, ret, structure, func, default) do
    quote do
      {:ok, unquote(ret)} <-
        unquote(item).(:force_update, {unquote(structure), unquote(func), unquote(default)})
    end
  end
end
