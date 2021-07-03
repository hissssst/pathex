defmodule Pathex.Lenses.Star do

  @moduledoc """
  Private module for `star()` lens
  """

  # Helpers

  defmacrop extend_if_ok(func, value, acc) do
    quote do
      case unquote(func).(unquote(value)) do
        {:ok, result} -> [result | unquote(acc)]
        :error        -> unquote(acc)
      end
    end
  end

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  # Lens

  @spec star() :: Pathex.t()
  def star() do
    fn
      :view, {%{} = map, func} ->
        map
        |> Enum.reduce([], fn {_key, value}, acc ->
          extend_if_ok(func, value, acc)
        end)
        |> wrap_ok()

      :view, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.reduce([], fn value, acc ->
          extend_if_ok(func, value, acc)
        end)
        |> :lists.reverse()
        |> wrap_ok()

      :view, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        Enum.reduce(kwd, [], fn {_key, value}, acc ->
          extend_if_ok(func, value, acc)
        end)
        |> :lists.reverse()
        |> wrap_ok()

      :view, {l, func} when is_list(l) ->
        Enum.reduce(l, [], fn value, acc ->
          extend_if_ok(func, value, acc)
        end)
        |> :lists.reverse()
        |> wrap_ok()

      :update, {%{} = map, func} ->
        map
        |> Map.new(fn {key, value} ->
          case func.(value) do
            {:ok, new_value} -> {key, new_value}
            :error           -> {key, value}
          end
        end)
        |> wrap_ok()

      :update, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, new_value} -> new_value
            :error           -> value
          end
        end)
        |> List.to_tuple()
        |> wrap_ok()

      :update, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        kwd
        |> Enum.map(fn {key, value} ->
          case func.(value) do
            {:ok, new_value} -> {key, new_value}
            :error           -> {key, value}
          end
        end)
        |> wrap_ok()

      :update, {l, func} when is_list(l) ->
        Enum.map(l, fn value ->
          case func.(value) do
            {:ok, new_value} -> new_value
            :error           -> value
          end
        end)
        |> wrap_ok()

      :delete, {%{} = map, func} ->
        map
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          case func.(value) do
            {:ok, _} -> acc
            :error   -> Map.put(acc, key, value)
          end
        end)
        |> wrap_ok()

      :delete, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.flat_map(fn value ->
          case func.(value) do
            {:ok, _} -> []
            :error   -> [value]
          end
        end)
        |> List.to_tuple()
        |> wrap_ok()

      :delete, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        kwd
        |> Enum.flat_map(fn {key, value} ->
          case func.(value) do
            {:ok, _} -> []
            :error   -> [{key, value}]
          end
        end)
        |> wrap_ok()

      :delete, {l, func} when is_list(l) ->
        Enum.flat_map(l, fn value ->
          case func.(value) do
            {:ok, _} -> []
            :error   -> [value]
          end
        end)
        |> wrap_ok()

      :force_update, {%{} = map, func, default} ->
        map
        |> Map.new(fn {key, value} ->
          case func.(value) do
            {:ok, v} -> {key, v}
            :error   -> {key, default}
          end
        end)
        |> wrap_ok()

      :force_update, {t, func, default} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, v} -> v
            :error   -> default
          end
        end)
        |> List.to_tuple()
        |> wrap_ok()

      :force_update, {[{a, _} | _] = kwd, func, default} when is_atom(a) ->
        kwd
        |> Enum.map(fn {key, value} ->
          case func.(value) do
            {:ok, v} -> {key, v}
            :error   -> {key, default}
          end
        end)
        |> wrap_ok()

      :force_update, {l, func, default} when is_list(l) ->
        l
        |> Enum.map(fn value ->
          case func.(value) do
            {:ok, v} -> v
            :error   -> default
          end
        end)
        |> wrap_ok()

      op, _ when op in ~w[view update delete force_update]a ->
        :error
    end
  end

end
