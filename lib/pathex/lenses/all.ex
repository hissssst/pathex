defmodule Pathex.Lenses.All do
  # Private module for `all()` lens
  # > see `Pathex.Lenses.all/0` documentation
  @moduledoc false

  # Helpers

  defmacrop at_pattern(pipe, pattern, do: code) do
    quote do
      case unquote(pipe) do
        unquote(pattern) -> unquote(code)
        other -> other
      end
    end
  end

  defmacrop cont(func, value, acc) do
    quote do
      case unquote(func).(unquote(value)) do
        {:ok, v} -> {:cont, {:ok, [v | unquote(acc)]}}
        :error -> {:halt, :error}
      end
    end
  end

  defmacrop reverse_if_ok(res) do
    quote do
      with {:ok, l} <- unquote(res) do
        {:ok, :lists.reverse(l)}
      end
    end
  end

  defmacrop bool_to_either(bool, ok) do
    quote do
      case unquote(bool) do
        true -> {:ok, unquote(ok)}
        false -> :error
      end
    end
  end

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  # Lens

  @spec all() :: Pathex.t()
  def all do
    fn
      :view, {%{} = map, func} ->
        Enum.reduce_while(map, {:ok, []}, fn {_key, value}, {_, acc} ->
          func |> cont(value, acc)
        end)

      :view, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.reduce_while({:ok, []}, fn value, {_, acc} ->
          func |> cont(value, acc)
        end)
        |> reverse_if_ok()

      :view, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        Enum.reduce_while(kwd, {:ok, []}, fn {_key, value}, {_, acc} ->
          func |> cont(value, acc)
        end)
        |> reverse_if_ok()

      :view, {l, func} when is_list(l) ->
        Enum.reduce_while(l, {:ok, []}, fn value, {_, acc} ->
          func |> cont(value, acc)
        end)
        |> reverse_if_ok()

      :update, {%{} = map, func} ->
        res =
          Enum.reduce_while(map, {:ok, []}, fn {key, value}, {_, acc} ->
            case func.(value) do
              {:ok, v} -> {:cont, {:ok, [{key, v} | acc]}}
              :error -> {:halt, :error}
            end
          end)

        with {:ok, pairs} <- res do
          {:ok, Map.new(pairs)}
        end

      :update, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        t
        |> Tuple.to_list()
        |> Enum.reduce_while({:ok, []}, fn value, {_, acc} ->
          func |> cont(value, acc)
        end)
        |> at_pattern({:ok, list}) do
          {:ok, list |> :lists.reverse() |> List.to_tuple()}
        end

      :update, {[{a, _} | _] = kwd, func} when is_atom(a) ->
        Enum.reduce_while(kwd, {:ok, []}, fn {key, value}, {_, acc} ->
          case func.(value) do
            {:ok, v} -> {:cont, {:ok, [{key, v} | acc]}}
            :error -> {:halt, :error}
          end
        end)
        |> reverse_if_ok()

      :update, {l, func} when is_list(l) ->
        Enum.reduce_while(l, {:ok, []}, fn value, {_, acc} ->
          cont(func, value, acc)
        end)
        |> reverse_if_ok()

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

      :delete, {list} when is_list(list) ->
        {:ok, []}

      :delete, {map} when is_map(map) ->
        {:ok, %{}}

      :inspect, _ ->
        "all()"

      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end
end
