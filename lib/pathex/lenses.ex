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
      :view, {{^head, v}, f} -> {:ok, f.(v)}
      :view, _ -> :error
      :update, {{^head, v}, f} -> {:ok, {head, f.(v)}}
      :update, _ -> :error
      :force_update, {{^head, v}, f, _} -> {:ok, {head, f.(v)}}
      :force_update, {{_, _}, _, d} -> {:ok, {head, d}}
      :force_update, _ -> :error
    end
  end

  @doc """
  Path function which works like unix path `./`

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
      _, x -> {:ok, :erlang.element(2, x).(:erlang.element(1, x))}
    end
  end

  @doc """
  Path function which works with **any** possible key it can find

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
          {_, v, _} -> {:ok, func.(v)}
        end
      :view, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        {:ok, func.(:erlang.element(1, t))}
      :view, {[{a, v} | _], func} when is_atom(a) ->
        {:ok, func.(v)}
      :view, {[v | _], func} ->
        {:ok, func.(v)}

      :update, {%{} = map, func} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none -> :error
          {k, v, _} -> {:ok, %{map | k => func.(v)}}
        end
      :update, {t, func} when is_tuple(t) and tuple_size(t) > 0 ->
        {:ok,  put_elem(t, 0, func.(:erlang.element(1, t)))}
      :update, {[{a, v} | tail], func} when is_atom(a) ->
        {:ok, [{a, func.(v)} | tail]}
      :update, {[v | tail], func} ->
        {:ok, [func.(v) | tail]}

      :force_update, {%{} = map, func, _} ->
        :maps.iterator(map)
        |> :maps.next()
        |> case do
          :none -> :error
          {k, v, _} -> {:ok, %{map | k => func.(v)}}
        end
      :force_update, {t, func, _} when is_tuple(t) and tuple_size(t) > 0 ->
        {:ok,  put_elem(t, 0, func.(:erlang.element(1, t)))}
      :force_update, {t, _, default} when is_tuple(t) ->
        {:ok, {default}}
      :force_update, {[{a, v} | tail], func, _} when is_atom(a) ->
        {:ok, [{a, func.(v)} | tail]}
      :force_update, {[v | tail], func, _} ->
        {:ok, [func.(v) | tail]}
      :force_update, {[], _, default} ->
        {:ok, [default]}
      op, _ when op in ~w[view update force_update]a ->
        :error
    end
  end

end
