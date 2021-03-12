defmodule Pathex.Lenses do

  @moduledoc """
  Module with collection of prebuilt paths
  """

  @doc """
  Path function for tuple with specified first element

  Example:
      iex> require Pathex; import Pathex
      iex> okl = Pathex.Lenses.either(:ok)
      iex> 8 = view! {:ok, 8}, okl
      iex> {:ok, 10} = set! {:ok, 8}, okl, 10
      iex> {:ok, 123} = force_set! {:error, :x}, okl, 123
  """
  @spec either(any()) :: Pathex.t()
  def either(head) do
    fn
      :view, {{^head, value}, f} -> f.(value)
      :view, _ -> :error

      :update, {{^head, value}, f} ->
        with {:ok, new_value} <- f.(value) do
          {:ok, {head, new_value}}
        end
      :update, _ -> :error

      :force_update, {{^head, value}, f, _} ->
        with {:ok, new_value} <- f.(value) do
          {:ok, {head, new_value}}
        end
      :force_update, {{_, _}, _, d} -> {:ok, {head, d}}
      :force_update, _ -> :error
    end
  end

  @doc """
  Path function which works like unix path `./`
  Works with every existing value (not only Enumerable)

  Example:
      iex> require Pathex
      iex> idl = Pathex.Lenses.id()
      iex> {:ok, 8} = Pathex.view 8, idl
      iex> {:ok, 9} = Pathex.set 8, idl, 9
      iex> {:ok, 9} = Pathex.force_set 8, idl, 9
  """
  @spec id() :: Pathex.t()
  def id do
    fn
      _, x -> :erlang.element(2, x).(:erlang.element(1, x))
    end
  end

  @doc """
  Path function which works with **any** possible key it can find
  It takes any key **and than** applies inner function (or concated path)

  Example:
      iex> require Pathex
      iex> anyl = Pathex.Lenses.any()
      iex> {:ok, 1} = Pathex.view %{x: 1}, anyl
      iex> {:ok, [9]} = Pathex.set  [8], anyl, 9
      iex> {:ok, [x: 1, y: 2]} = Pathex.force_set [x: 0, y: 2], anyl, 1

  Note that force setting value to empty map has undefined behaviour
  and therefore returns an error:
      iex> require Pathex
      iex> anyl = Pathex.Lenses.any()
      iex> :error = Pathex.force_set(%{}, anyl, :well)

  And note that this lens has keywords at head of list at a higher priority
  than non-keyword heads:
      iex> require Pathex
      iex> anyl = Pathex.Lenses.any()
      iex> {:ok, [{:x, 1}, 2]} = Pathex.set([{:x, 0}, 2], anyl, 1)
      iex> {:ok, [1, {:x, 2}]} = Pathex.set([0, {:x, 2}], anyl, 1)
      iex> {:ok, [1, 2]} = Pathex.set([{"some_tuple", "here"}, 2], anyl, 1)
  """
  @spec any() :: Pathex.t()
  def any do
    fn
      :view, {%{} = map, func} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none -> :error
          {_, v, _} -> func.(v)
        end
      :view, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        func.(:erlang.element(1, t))
      :view, {[{a, v} | _], func} when is_atom(a) ->
        func.(v)
      :view, {[v | _], func} ->
        func.(v)

      :update, {%{} = map, func} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none -> :error
          {key, value, _} ->
            with {:ok, new_value} <- func.(value) do
              {:ok, %{map | key => new_value}}
            end
        end
      :update, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        with {:ok, new_element} <- func.(:erlang.element(1, t)) do
          {:ok, :erlang.setelement(1, t, new_element)}
        end
      :update, {[{a, value} | tail], func} when is_atom(a) ->
        with {:ok, new_value} <- func.(value) do
          {:ok, [{a, new_value} | tail]}
        end
      :update, {[value | tail], func} ->
        with {:ok, new_value} <- func.(value) do
          {:ok, [new_value | tail]}
        end

      :force_update, {%{} = map, func, _} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none -> :error
          {key, value, _} ->
            with {:ok, new_value} <- func.(value) do
              {:ok, %{map | key => new_value}}
            end
        end
      :force_update, {t, func, _} when is_tuple(t) and tuple_size(t) > 0 ->
        with {:ok, new_element} <- func.(:erlang.element(1, t)) do
          {:ok, :erlang.setelement(1, t, new_element)}
        end
      :force_update, {t, _, default} when is_tuple(t) ->
        {:ok, {default}}
      :force_update, {[{a, value} | tail], func, _} when is_atom(a) ->
        with {:ok, new_value} <- func.(value) do
          {:ok, [{a, new_value} | tail]}
        end
      :force_update, {[value | tail], func, _} ->
        with {:ok, new_value} <- func.(value) do
          {:ok, [new_value | tail]}
        end
      :force_update, {[], _, default} ->
        {:ok, [default]}
      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end

  # Helpers for `all` lens

  defmacrop at_pattern(pipe, pattern, do: code) do
    quote do
      case unquote(pipe) do
        unquote(pattern) -> unquote(code)
        other            -> other
      end
    end
  end

  defmacrop cont(func, value, acc) do
    quote do
      case unquote(func).(unquote(value)) do
        {:ok, v} -> {:cont, {:ok, [v | unquote(acc)]}}
        :error   -> {:halt, :error}
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

  defmacrop wrap_ok(code) do
    quote(do: {:ok, unquote(code)})
  end

  @doc """
  Path function which works with **all** possible keys it can find
  It takes all keys **and than** applies inner function (or concated path)
  If any application fails, this lens returns `:error`

  Example:
      iex> require Pathex; import Pathex
      iex> alll = Pathex.Lenses.all()
      iex> [%{x: 1}, [x: 2]] = Pathex.over!([%{x: 0}, [x: 1]], alll ~> path(:x), fn x -> x + 1 end)
      iex> [1, 2, 3] = Pathex.view!(%{x: 1, y: 2, z: 3}, alll) |> Enum.sort()
      iex> {:ok, [x: 2, y: 2]} = Pathex.set([x: 1, y: 0], alll, 2)
  """
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
              :error   -> {:halt, :error}
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
            :error   -> {:halt, :error}
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

      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end

  defmacro extend_if_ok(func, value, acc) do
    quote do
      case unquote(func).(unquote(value)) do
        {:ok, result} -> [result | unquote(acc)]
        :error        -> unquote(acc)
      end
    end
  end

  @doc """
  Path function which applies inner function (or concated path-closure)
  to every value it can apply it to

  Example:
      iex> require Pathex; import Pathex
      iex> starl = Pathex.Lenses.star()
      iex> [1, 2] = Pathex.view!(%{x: [1], y: [2], z: 3}, starl ~> path(0)) |> Enum.sort()
      iex> %{x: %{y: 1}, z: [3]} = Pathex.set!(%{x: %{y: 0}, z: [3]}, starl ~> path(:y, :map), 1)
      iex> {:ok, [1, 2, 3]} = Pathex.view([x: 1, y: 2, z: 3], starl)

  > Note:  
  > Force update works the same way as `all` lens  
  > And update leaves unusable data unchanged
  """
  @spec star() :: Pathex.t()
  def star do
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

      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end

end
