defmodule Pathex.Lenses.All do
  # Private module for `all()` lens
  # > see `Pathex.Lenses.all/0` documentation
  @moduledoc false

  # Helpers

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  # Lens

  @spec all() :: Pathex.t()
  def all do
    fn
      :view, {map, func} when is_map(map) ->
        map
        |> :maps.iterator()
        |> map_view(func, [])

      :view, {tuple, func} when is_tuple(tuple) ->
        tuple_view(tuple, func, 1, tuple_size(tuple), [])

      :view, {[{atom, _} | _] = keyword, func} when is_atom(atom) ->
        keyword_view(keyword, func, [])

      :view, {list, func} when is_list(list) ->
        list_view(list, func, [])

      :update, {map, func} when is_map(map) ->
        map
        |> :maps.iterator()
        |> map_update(func, %{})

      :update, {tuple, func} when is_tuple(tuple) ->
        tuple_update(tuple, func, 1, tuple_size(tuple))

      :update, {[{atom, _} | _] = keyword, func} when is_atom(atom) ->
        keyword_update(keyword, func, [])

      :update, {list, func} when is_list(list) ->
        list_update(list, func, [])

      :force_update, {%{} = map, func, default} ->
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

      :force_update, {l, func, default} when is_list(l) ->
        l
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, v} -> v
            :error -> default
          end
        end)
        |> wrap_ok()

      :delete, {map, func} when is_map(map) ->
        map
        |> :maps.iterator()
        |> map_delete(func, %{})

      :delete, {tuple, func} when is_tuple(tuple) ->
        tuple_delete(tuple, func, 1, tuple_size(tuple))

      :delete, {[{atom, _} | _] = keyword, func} when is_atom(atom) ->
        keyword_delete(keyword, func, [])

      :delete, {list, func} when is_list(list) ->
        list_delete(list, func, [])

      :inspect, _ ->
        {:all, [], []}

      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end

  # View

  defp list_view([head | tail], func, acc) do
    case func.(head) do
      {:ok, result} -> list_view(tail, func, [result | acc])
      :error -> :error
    end
  end

  defp list_view([], _func, acc), do: {:ok, :lists.reverse(acc)}

  defp keyword_view([{atom, value} | tail], func, acc) when is_atom(atom) do
    case func.(value) do
      {:ok, result} -> keyword_view(tail, func, [result | acc])
      :error -> :error
    end
  end

  defp keyword_view([], _func, acc), do: {:ok, :lists.reverse(acc)}
  defp keyword_view(_, _, _), do: :error

  defp map_view(iterator, func, acc) do
    case :maps.next(iterator) do
      :none ->
        {:ok, acc}

      {_key, value, iterator} ->
        case func.(value) do
          {:ok, result} ->
            map_view(iterator, func, [result | acc])

          :error ->
            :error
        end
    end
  end

  defp tuple_view(_, _, iterator, size, acc) when iterator > size, do: {:ok, :lists.reverse(acc)}

  defp tuple_view(tuple, func, iterator, size, acc) do
    case func.(:erlang.element(iterator, tuple)) do
      {:ok, result} -> tuple_view(tuple, func, iterator + 1, size, [result | acc])
      :error -> :error
    end
  end

  # Update

  defp list_update([head | tail], func, acc) do
    case func.(head) do
      {:ok, result} -> list_update(tail, func, [result | acc])
      :error -> :error
    end
  end

  defp list_update([], _func, acc), do: {:ok, :lists.reverse(acc)}

  defp keyword_update([{atom, value} | tail], func, acc) when is_atom(atom) do
    case func.(value) do
      {:ok, result} -> keyword_update(tail, func, [{atom, result} | acc])
      :error -> :error
    end
  end

  defp keyword_update([], _func, acc), do: {:ok, :lists.reverse(acc)}
  defp keyword_update(_, _, _), do: :error

  defp map_update(iterator, func, acc) do
    case :maps.next(iterator) do
      :none ->
        {:ok, acc}

      {key, value, iterator} ->
        case func.(value) do
          {:ok, result} ->
            map_update(iterator, func, Map.put(acc, key, result))

          :error ->
            :error
        end
    end
  end

  defp tuple_update(tuple, _, iterator, size) when iterator > size, do: {:ok, tuple}

  defp tuple_update(tuple, func, iterator, size) do
    import :erlang, only: [element: 2, setelement: 3]

    case func.(element(iterator, tuple)) do
      :error ->
        :error

      {:ok, result} ->
        tuple = setelement(iterator, tuple, result)
        tuple_update(tuple, func, iterator + 1, size)
    end
  end

  # Delete

  defp list_delete([head | tail], func, acc) do
    case func.(head) do
      {:ok, result} -> list_delete(tail, func, [result | acc])
      :delete_me -> list_delete(tail, func, acc)
      :error -> :error
    end
  end

  defp list_delete([], _func, acc), do: {:ok, :lists.reverse(acc)}

  defp keyword_delete([{atom, value} | tail], func, acc) when is_atom(atom) do
    case func.(value) do
      {:ok, result} -> keyword_delete(tail, func, [{atom, result} | acc])
      :delete_me -> keyword_delete(tail, func, acc)
      :error -> :error
    end
  end

  defp keyword_delete([], _func, acc), do: {:ok, :lists.reverse(acc)}
  defp keyword_delete(_, _, _), do: :error

  defp map_delete(iterator, func, acc) do
    case :maps.next(iterator) do
      :none ->
        {:ok, acc}

      {key, value, iterator} ->
        case func.(value) do
          {:ok, result} ->
            map_delete(iterator, func, Map.put(acc, key, result))

          :delete_me ->
            map_delete(iterator, func, acc)

          :error ->
            :error
        end
    end
  end

  defp tuple_delete(tuple, _, iterator, size) when iterator > size, do: {:ok, tuple}

  defp tuple_delete(tuple, func, iterator, size) do
    import :erlang, only: [element: 2, setelement: 3, delete_element: 2]

    case func.(element(iterator, tuple)) do
      :error ->
        :error

      :delete_me ->
        tuple = delete_element(iterator, tuple)
        tuple_delete(tuple, func, iterator, size - 1)

      {:ok, result} ->
        tuple = setelement(iterator, tuple, result)
        tuple_delete(tuple, func, iterator + 1, size)
    end
  end
end
