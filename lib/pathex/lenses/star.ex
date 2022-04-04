defmodule Pathex.Lenses.Star do
  # Private module for `star()` lens
  @moduledoc false

  # Helpers

  defmacrop extend_if_ok(status, func, value, acc) do
    quote do
      case unquote(func).(unquote(value)) do
        {:ok, result} -> {:ok, [result | unquote(acc)]}
        :error -> {unquote(status), unquote(acc)}
      end
    end
  end

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  # Lens

  @spec star() :: Pathex.t()
  def star do
    fn
      :view, {%{} = map, func} ->
        map
        |> Enum.reduce({:error, []}, fn {_key, value}, {status, acc} ->
          extend_if_ok(status, func, value, acc)
        end)
        |> case do
          {:error, _} -> :error
          {:ok, res} -> {:ok, res}
        end

      :view, {tuple, func} when is_tuple(tuple) and tuple_size(tuple) > 0 ->
        tuple
        |> Tuple.to_list()
        |> Enum.reduce({:error, []}, fn value, {status, acc} ->
          extend_if_ok(status, func, value, acc)
        end)
        |> case do
          {:error, _} -> :error
          {:ok, res} -> {:ok, :lists.reverse(res)}
        end

      :view, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        kwd
        |> Enum.reduce({:error, []}, fn {_key, value}, {status, acc} ->
          extend_if_ok(status, func, value, acc)
        end)
        |> case do
          {:error, _} -> :error
          {:ok, res} -> {:ok, :lists.reverse(res)}
        end

      :view, {list, func} when is_list(list) ->
        list
        |> Enum.reduce({:error, []}, fn value, {status, acc} ->
          extend_if_ok(status, func, value, acc)
        end)
        |> case do
          {:error, _} -> :error
          {:ok, res} -> {:ok, :lists.reverse(res)}
        end

      :update, {%{} = map, func} ->
        Enum.reduce(map, {:error, %{}}, fn {key, value}, {status, acc} ->
          case func.(value) do
            {:ok, new_value} -> {:ok, Map.put(acc, key, new_value)}
            :error -> {status, Map.put(acc, key, value)}
          end
        end)
        |> case do
          {:error, _} -> :error
          {:ok, map} -> {:ok, map}
        end

      :update, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.reduce({:error, []}, fn value, {status, list} ->
          case func.(value) do
            {:ok, new_value} -> {:ok, [new_value | list]}
            :error -> {status, [value | list]}
          end
        end)
        |> case do
          {:error, _} -> :error
          {:ok, l} -> {:ok, List.to_tuple(:lists.reverse(l))}
        end

      :update, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        Enum.reduce(kwd, {:error, []}, fn {key, value}, {status, list} ->
          case func.(value) do
            {:ok, new_value} -> {:ok, [{key, new_value} | list]}
            :error -> {status, [{key, value} | list]}
          end
        end)
        |> case do
          {:error, _} -> :error
          {:ok, l} -> {:ok, :lists.reverse(l)}
        end

      :update, {list, func} when is_list(list) ->
        Enum.reduce(list, {:error, []}, fn value, {status, list} ->
          case func.(value) do
            {:ok, new_value} -> {:ok, [new_value | list]}
            :error -> {status, [value | list]}
          end
        end)
        |> case do
          {:error, _} -> :error
          {:ok, l} -> {:ok, :lists.reverse(l)}
        end

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

      :delete, {tuple} when is_tuple(tuple) ->
        {:ok, {}}

      # Special case for keyword is not necessary
      :delete, {list} when is_list(list) ->
        {:ok, []}

      :delete, {map} when is_map(map) ->
        {:ok, %{}}

      :inspect, _ ->
        "star()"

      op, _ when op in ~w[delete view update force_update]a ->
        :error
    end
  end
end
