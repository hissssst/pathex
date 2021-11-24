defmodule Pathex.Lenses do
  @moduledoc """
  Module with collection of prebuilt paths
  """

  alias __MODULE__.{Some, Any, All, Star}

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
  def any, do: Any.any()

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
  def all, do: All.all()

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

  Think of this function as `filter`. It is particulary useful for filtering  
  and selecting needed values with custom functions or `matching/1` macro

  Example:
      iex> require Pathex; import Pathex; require Pathex.Lenses
      iex> starl = Pathex.Lenses.star()
      iex> structure = [{1, 4}, {2, 8}, {3, 6}, {4, 10}]
      iex> #
      iex> # For example we want to select all tuples with first element greater than 2
      iex> #
      iex> greater_than_2 = Pathex.Lenses.matching({x, _} when x > 2)
      iex> {:ok, [{3, 6}, {4, 10}]} = Pathex.view(structure, starl ~> greater_than_2)
  """
  @spec star() :: Pathex.t()
  def star, do: Star.star()

  @doc """
  Path function which applies inner function (or concated path-closure)
  to the first value it can apply it to

  Example:
      iex> require Pathex; import Pathex
      iex> somel = Pathex.Lenses.some()
      iex> 11 = Pathex.view!([x: [11], y: [22], z: 33], somel ~> path(0))
      iex> [x: %{y: 1}, z: %{y: 0}] = Pathex.set!([x: %{y: 0}, z: %{y: 0}], somel ~> path(:y, :map), 1)
      iex> {:ok, 1} = Pathex.view([x: 1, y: 2, z: 3], somel)

  > Note:  
  > Force update fails for empty structures

  Think of this function as `star() ~> any()` but optimized to work with only first element
  """
  @spec some() :: Pathex.t()
  def some, do: Some.some()

  @doc """
  This macro creates path-closure which works like `id/0` but
  successes only for matching data.

  This function is useful when composed with `star/0` and `some/0`

  Example:
      iex> import Pathex.Lenses; import Pathex
      iex> adminl = matching(%{role: :admin})
      iex> {:ok, %{name: "Name", role: :admin}} = Pathex.view(%{name: "Name", role: :admin}, adminl)
      iex> :error = Pathex.view(%{}, adminl)

      iex> import Pathex.Lenses; import Pathex
      iex> dots2d = [{1, 1}, {1, 5}, {3, 0}, {4, 3}]
      iex> higher_than_2 = matching({_x, y} when y > 2)
      iex> {:ok, [{1, 5}, {4, 3}]} = Pathex.view(dots2d, star() ~> higher_than_2)
  """
  # This case is just an optimization for `id/0`-like lens
  defmacro matching({:_, meta, ctx}) when is_list(meta) and (is_nil(ctx) or is_atom(ctx)) do
    quote do
      fn
        _, x -> :erlang.element(2, x).(:erlang.element(1, x))
      end
    end
  end

  defmacro matching({:when, _, [pattern, condition]}) do
    quote do
      fn
        op, {unquote(pattern) = x, func} when op in ~w[update view]a and unquote(condition) ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} when unquote(condition) ->
          func.(x)

        :force_update, {_x, func, default} ->
          default

        op, _ when op in ~w[view update force_update]a ->
          :error
      end
    end
  end

  defmacro matching(pattern) do
    quote do
      fn
        op, {unquote(pattern) = x, func} when op in ~w[update view]a ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} ->
          func.(x)

        :force_update, {_x, func, default} ->
          default

        op, _ when op in ~w[view update force_update]a ->
          :error
      end
    end
  end

  @deprecated """
  Use `matching({:ok, _}) ~> path(1)` macro with `path(1)` instead.  
  Will be removed in future releases.
  """
  def either(head) do
    fn
      :view, {{^head, value}, f} ->
        f.(value)

      :view, _ ->
        :error

      :update, {{^head, value}, f} ->
        with {:ok, new_value} <- f.(value) do
          {:ok, {head, new_value}}
        end

      :update, _ ->
        :error

      :force_update, {{^head, value}, f, _} ->
        with {:ok, new_value} <- f.(value) do
          {:ok, {head, new_value}}
        end

      :force_update, {{_, _}, _, d} ->
        {:ok, {head, d}}

      :force_update, _ ->
        :error
    end
  end

  @deprecated """
  Use `matching(_)` instead.  
  Will be removed in future releases.
  """
  def id do
    fn
      _, x -> :erlang.element(2, x).(:erlang.element(1, x))
    end
  end
end
