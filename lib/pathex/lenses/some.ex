defmodule Pathex.Lenses.Some do
  # Private module for `some()` lens
  # > see `Pathex.Lenses.some/0` documentation
  @moduledoc false

  def some do
    fn
      :view, {%{} = map, func} ->
        Enum.find_value(map, :error, fn {_k, v} ->
          with :error <- func.(v) do
            false
          end
        end)

      :view, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        Enum.find_value(kwd, :error, fn {_k, v} ->
          with :error <- func.(v) do
            false
          end
        end)

      :view, {l, func} when is_list(l) ->
        Enum.find_value(l, :error, fn v ->
          with :error <- func.(v) do
            false
          end
        end)

      :view, {t, func} when is_tuple(t) ->
        Enum.find_value(Tuple.to_list(t), :error, fn v ->
          with :error <- func.(v) do
            false
          end
        end)

      :update, {%{} = map, func} ->
        found =
          Enum.find_value(map, :error, fn {k, v} ->
            case func.(v) do
              {:ok, v} -> {k, v}
              :error -> false
            end
          end)

        with {k, v} <- found do
          {:ok, Map.put(map, k, v)}
        end

      # TODO: optimize through reduce and prepend
      :update, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        found =
          Enum.find_value(kwd, :error, fn {k, v} ->
            case func.(v) do
              {:ok, v} -> {k, v}
              :error -> false
            end
          end)

        with {k, v} <- found do
          {:ok, Keyword.put(kwd, k, v)}
        end

      :update, {l, func} when is_list(l) ->
        Enum.reduce(l, {:error, []}, fn
          v, {:error, acc} ->
            case func.(v) do
              {:ok, v} -> {:ok, [v | acc]}
              :error -> {:error, [v | acc]}
            end

          v, {:ok, acc} ->
            {:ok, [v | acc]}
        end)
        |> case do
          {:error, _} -> :error
          {:ok, list} -> {:ok, :lists.reverse(list)}
        end

      :update, {t, func} when is_tuple(t) ->
        t
        |> Tuple.to_list()
        |> Enum.reduce_while(1, fn v, index ->
          case func.(v) do
            {:ok, v} -> {:halt, {index, v}}
            :error -> {:cont, index + 1}
          end
        end)
        |> case do
          {index, v} ->
            {:ok, :erlang.setelement(index, t, v)}

          _ ->
            :error
        end

      :force_update, {%{} = map, func, default} ->
        map
        |> Enum.find_value(:error, fn {k, v} ->
          case func.(v) do
            {:ok, v} -> {k, v}
            :error -> false
          end
        end)
        |> case do
          {k, v} ->
            {:ok, Map.put(map, k, v)}

          :error ->
            map
            |> :maps.iterator()
            |> :maps.next()
            |> case do
              {k, _, _} ->
                {:ok, Map.put(map, k, default)}

              :none ->
                :error
            end
        end

      :force_update, {[{a, _} | _] = kwd, func, default} when is_atom(a) ->
        kwd
        |> Enum.find_value(:error, fn {k, v} ->
          case func.(v) do
            {:ok, v} -> {k, v}
            :error -> false
          end
        end)
        |> case do
          {k, v} ->
            {:ok, Keyword.put(kwd, k, v)}

          :error ->
            {:ok, Keyword.put(kwd, a, default)}
        end

      :force_update, {list, func, default} when is_list(list) ->
        list
        |> Enum.reduce({:error, []}, fn
          v, {:error, acc} ->
            case func.(v) do
              {:ok, v} -> {:ok, [v | acc]}
              :error -> {:error, [v | acc]}
            end

          v, {:ok, acc} ->
            {:ok, [v | acc]}
        end)
        |> case do
          {:error, list} ->
            [_first | list] = :lists.reverse(list)
            {:ok, [default | list]}

          {:ok, list} ->
            {:ok, :lists.reverse(list)}
        end

      :force_update, {t, func, default} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.reduce_while(1, fn v, index ->
          case func.(v) do
            {:ok, v} -> {:halt, {index, v}}
            :error -> {:cont, index + 1}
          end
        end)
        |> case do
          {index, v} ->
            {:ok, :erlang.setelement(index, t, v)}

          _ ->
            {:ok, :erlang.setelement(0, t, default)}
        end

      :delete, {%{} = map} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none ->
            :error

          {key, _value, _iter} ->
            {:ok, Map.delete(map, key)}
        end

      :delete, {t} when is_tuple(t) and tuple_size(t) > 0 ->
        {:ok, :erlang.delete_element(1, t)}

      :delete, {[_ | tail]} ->
        {:ok, tail}

      :inspect, _ ->
        "some()"

      op, _ when op in ~w[delete view update force_update]a ->
        :error
    end
  end
end
