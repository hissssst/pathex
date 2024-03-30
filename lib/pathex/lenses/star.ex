defmodule Pathex.Lenses.Star do
  # Private module for `star()` lens
  @moduledoc false

  # Helpers

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  defmacrop either_empty(code) do
    quote do
      case unquote(code) do
        [] -> :error
        other -> {:ok, other}
      end
    end
  end

  # Lens

  @spec star() :: Pathex.t()
  def star do
    fn
      :view, {%{} = map, func} ->
        map
        |> :maps.iterator()
        |> map_view(func)
        |> either_empty()

      :view, {tuple, func} when is_tuple(tuple) and tuple_size(tuple) > 0 ->
        either_empty(tuple_view(tuple, 1, tuple_size(tuple), func))

      :view, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        either_empty(keyword_view(kwd, func))

      :view, {list, func} when is_list(list) ->
        either_empty(list_view(list, func))

      :update, {%{} = map, func} ->
        map
        |> :maps.iterator()
        |> map_update(func, false, %{})

      :force_update, {{}, _func, default} ->
        {:ok, {default}}

      :update, {tuple, func} when is_tuple(tuple) ->
        tuple_update(tuple, func, 1, tuple_size(tuple), false)

      :update, {[{a, _} | _] = keyword, func} when is_atom(a) ->
        keyword_update(keyword, func, false, [])

      :update, {list, func} when is_list(list) ->
        list_update(list, func, false, [])

      :force_update, {map, func, default} when is_map(map) and map_size(map) > 0 ->
        map
        |> Map.new(fn {key, value} ->
          case func.(value) do
            {:ok, v} -> {key, v}
            :error -> {key, default}
          end
        end)
        |> wrap_ok()

      :force_update, {t, func, default} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, v} -> v
            :error -> default
          end
        end)
        |> List.to_tuple()
        |> wrap_ok()

      :force_update, {[{a, _} | _] = kwd, func, default} when is_atom(a) ->
        kwd
        |> Enum.map(fn {key, value} ->
          case func.(value) do
            {:ok, v} -> {key, v}
            :error -> {key, default}
          end
        end)
        |> wrap_ok()

      :force_update, {[], _func, default} ->
        {:ok, [default]}

      :force_update, {l, func, default} when is_list(l) ->
        l
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, v} -> v
            :error -> default
          end
        end)
        |> wrap_ok()

      :delete, {tuple, func} when is_tuple(tuple) ->
        tuple_delete(tuple, func, 1, tuple_size(tuple), false)

      :delete, {map, func} when is_map(map) ->
        map
        |> :maps.iterator()
        |> map_delete(func, false, %{})

      :delete, {[{a, _} | _] = keyword, func} when is_atom(a) ->
        keyword_delete(keyword, func, false, [])

      :delete, {list, func} when is_list(list) ->
        list_delete(list, func, false, [])

      :inspect, _ ->
        {:star, [], []}

      op, _ when op in ~w[delete view update force_update]a ->
        :error
    end
  end

  defp map_view(iterator, func) do
    case :maps.next(iterator) do
      :none ->
        []

      {_key, value, iterator} ->
        case func.(value) do
          {:ok, res} -> [res | map_view(iterator, func)]
          :error -> map_view(iterator, func)
        end
    end
  end

  defp tuple_view(_tuple, i, length, _func) when i > length, do: []

  defp tuple_view(tuple, i, length, func) do
    i
    |> :erlang.element(tuple)
    |> func.()
    |> case do
      {:ok, res} -> [res | tuple_view(tuple, i + 1, length, func)]
      :error -> tuple_view(tuple, i + 1, length, func)
    end
  end

  defp keyword_view([{a, v} | tail], func) when is_atom(a) do
    case func.(v) do
      {:ok, res} -> [res | keyword_view(tail, func)]
      :error -> keyword_view(tail, func)
    end
  end

  defp keyword_view([_ | tail], func), do: keyword_view(tail, func)
  defp keyword_view([], _func), do: []

  defp list_view([head | tail], func) do
    case func.(head) do
      {:ok, res} -> [res | list_view(tail, func)]
      :error -> list_view(tail, func)
    end
  end

  defp list_view([], _func), do: []

  defp map_update(iterator, func, status, acc) do
    case :maps.next(iterator) do
      :none ->
        case status do
          true -> {:ok, acc}
          false -> :error
        end

      {key, value, iterator} ->
        case func.(value) do
          {:ok, res} -> map_update(iterator, func, true, Map.put(acc, key, res))
          :error -> map_update(iterator, func, status, Map.put(acc, key, value))
        end
    end
  end

  defp list_update([], _, false, _), do: :error
  defp list_update([], _, _true, head_acc), do: {:ok, :lists.reverse(head_acc)}

  defp list_update([head | tail], func, called?, head_acc) do
    case func.(head) do
      {:ok, new_value} ->
        list_update(tail, func, true, [new_value | head_acc])

      :error ->
        list_update(tail, func, called?, [head | head_acc])
    end
  end

  # defp tuple_update(list, func, iterator, tuple_size, called? \\ false)
  defp tuple_update(_, _, iterator, tuple_size, false) when iterator > tuple_size, do: :error
  defp tuple_update(t, _, iterator, tuple_size, _true) when iterator > tuple_size, do: t

  defp tuple_update(tuple, func, iterator, tuple_size, called?) do
    case func.(:erlang.element(iterator, tuple)) do
      {:ok, new_value} ->
        iterator
        |> :erlang.setelement(tuple, new_value)
        |> tuple_update(func, iterator + 1, tuple_size, true)

      :error ->
        tuple_update(tuple, func, iterator + 1, tuple_size, called?)
    end
  end

  # defp keyword_update(keyword, func, called? \\ false, head_acc \\ [])
  defp keyword_update([], _, false, _), do: :error
  defp keyword_update([], _, _true, head_acc), do: {:ok, :lists.reverse(head_acc)}

  defp keyword_update([{key, value} = head | tail], func, called?, head_acc) when is_atom(key) do
    case func.(value) do
      {:ok, new_value} ->
        keyword_update(tail, func, true, [{key, new_value} | head_acc])

      :error ->
        keyword_update(tail, func, called?, [head | head_acc])
    end
  end

  defp keyword_update([head | tail], func, called?, head_acc) do
    keyword_update(tail, func, called?, [head | head_acc])
  end

  defp map_delete(iterator, func, status, acc) do
    case :maps.next(iterator) do
      :none ->
        case status do
          true -> {:ok, acc}
          false -> :error
        end

      {key, value, iterator} ->
        case func.(value) do
          :delete_me -> map_delete(iterator, func, true, acc)
          {:ok, res} -> map_delete(iterator, func, true, Map.put(acc, key, res))
          :error -> map_delete(iterator, func, status, Map.put(acc, key, value))
        end
    end
  end

  # defp list_delete(list, func, called? \\ false, head_acc \\ [])
  defp list_delete([], _, false, _), do: :error
  defp list_delete([], _, _true, head_acc), do: {:ok, :lists.reverse(head_acc)}

  defp list_delete([head | tail], func, called?, head_acc) do
    case func.(head) do
      {:ok, new_value} ->
        list_delete(tail, func, true, [new_value | head_acc])

      :delete_me ->
        list_delete(tail, func, true, head_acc)

      :error ->
        list_delete(tail, func, called?, [head | head_acc])
    end
  end

  # defp tuple_delete(list, func, iterator, tuple_size, called? \\ false)
  defp tuple_delete(_, _, iterator, tuple_size, false) when iterator > tuple_size, do: :error
  defp tuple_delete(t, _, iterator, tuple_size, _true) when iterator > tuple_size, do: t

  defp tuple_delete(tuple, func, iterator, tuple_size, called?) do
    case func.(:erlang.element(iterator, tuple)) do
      {:ok, new_value} ->
        iterator
        |> :erlang.setelement(tuple, new_value)
        |> tuple_delete(func, iterator + 1, tuple_size, true)

      :delete_me ->
        iterator
        |> :erlang.delete_element(tuple)
        |> tuple_delete(func, iterator, tuple_size - 1, true)

      :error ->
        tuple_delete(tuple, func, iterator + 1, tuple_size, called?)
    end
  end

  # defp keyword_delete(keyword, func, called? \\ false, head_acc \\ [])
  defp keyword_delete([], _, false, _), do: :error
  defp keyword_delete([], _, _true, head_acc), do: {:ok, :lists.reverse(head_acc)}

  defp keyword_delete([{key, value} = head | tail], func, called?, head_acc) do
    case func.(value) do
      {:ok, new_value} ->
        keyword_delete(tail, func, true, [{key, new_value} | head_acc])

      :delete_me ->
        keyword_delete(tail, func, true, head_acc)

      :error ->
        keyword_delete(tail, func, called?, [head | head_acc])
    end
  end
end
