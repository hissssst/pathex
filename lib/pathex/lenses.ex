defmodule Pathex.Lenses do
  @moduledoc """
  Module with collection of prebuilt paths
  """

  alias __MODULE__.{Some, Any, All, Star, Matching, Filtering}

  @doc """
  Path function which works with **any** possible key it can find
  It takes any key **and than** applies inner function (or concated path)

  ## Example

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
  @doc export: true
  @spec any() :: Pathex.t()
  def any, do: Any.any()

  @doc """
  Path function which works with **all** possible keys it can find
  It takes all keys **and than** applies inner function (or concated path)
  If any application fails, this lens returns `:error`

  ## Example

      iex> require Pathex; import Pathex
      iex> alll = Pathex.Lenses.all()
      iex> Pathex.over!([%{x: 0}, [x: 1]], alll ~> path(:x), fn x -> x + 1 end)
      [%{x: 1}, [x: 2]]
      iex> Pathex.view!(%{x: 1, y: 2, z: 3}, alll) |> Enum.sort()
      [1, 2, 3]
      iex> Pathex.set([x: 1, y: 0], alll, 2)
      {:ok, [x: 2, y: 2]}
  """
  @doc export: true
  @spec all() :: Pathex.t()
  def all, do: All.all()

  @doc """
  Path function which applies inner function (or concated path-closure)
  to every value it can apply it to

  ## Example

      iex> require Pathex; import Pathex
      iex> starl = Pathex.Lenses.star()
      iex> Pathex.view!(%{x: [1], y: [2], z: 3}, starl ~> path(0)) |> Enum.sort()
      [1, 2]
      iex> Pathex.set!(%{x: %{y: 0}, z: [3]}, starl ~> path(:y, :map), 1)
      %{x: %{y: 1}, z: [3]}
      iex> Pathex.view([x: 1, y: 2, z: 3], starl)
      {:ok, [1, 2, 3]}

  > Note:  
  > It returns :error when no data was found or changed

  Think of this function as `filter_map`. It is particularly useful for filtering  
  and selecting needed values with custom functions or `matching/1` macro

  ## Example

      iex> require Pathex; import Pathex; require Pathex.Lenses
      iex> starl = Pathex.Lenses.star()
      iex> structure = [{1, 4}, {2, 8}, {3, 6}, {4, 10}]
      iex> #
      iex> # For example we want to select all tuples with first element greater than 2
      iex> #
      iex> greater_than_2 = Pathex.Lenses.matching({x, _} when x > 2)
      iex> Pathex.view(structure, starl ~> greater_than_2)
      {:ok, [{3, 6}, {4, 10}]}
  """
  @doc export: true
  @spec star() :: Pathex.t()
  def star, do: Star.star()

  @doc """
  Path function which applies inner function (or concated path-closure)
  to the first value it can apply it to

  ## Example

      iex> require Pathex; import Pathex
      iex> somel = Pathex.Lenses.some()
      iex> Pathex.view!([x: [11], y: [22], z: 33], somel ~> path(0))
      11
      iex> Pathex.set!([x: %{y: 0}, z: %{y: 0}], somel ~> path(:y, :map), 1)
      [x: %{y: 1}, z: %{y: 0}]
      iex> Pathex.view([x: 1, y: 2, z: 3], somel)
      {:ok, 1}

  > Note:  
  > Force update fails for empty structures

  Think of this function as `star() ~> any()` but optimized to work with only first element
  """
  @doc export: true
  @spec some() :: Pathex.t()
  def some, do: Some.some()

  @doc """
  This macro creates path-closure which successes only when input matches the `pattern`.
  The `pattern` can be just a pattern or a pattern with `when`. You can write this patterns
  just like you'd write them in `case`

  This function is useful when composed with `star/0` and `some/0`

  > Note:  
  > In terms of functional programming, such conditional lenses are called prisms

  ## Example

      iex> import Pathex.Lenses; import Pathex
      iex> adminl = matching(%{role: :admin})
      iex> {:ok, %{name: "Name", role: :admin}} = Pathex.view(%{name: "Name", role: :admin}, adminl)
      iex> :error = Pathex.view(%{}, adminl)

      iex> import Pathex.Lenses; import Pathex
      iex> dots2d = [{1, 1}, {1, 5}, {3, 0}, {4, 3}]
      iex> higher_than_2 = matching({_x, y} when y > 2)
      iex> {:ok, [{1, 5}, {4, 3}]} = Pathex.view(dots2d, star() ~> higher_than_2)
  """
  @doc export: true
  defmacro matching(pattern) do
    Matching.matching_func(pattern)
  end

  @doc """
  This macro creates path-closure successes only when `predicate` returns truthy value.
  `predicate` is a function which takes a structures upon which the path is called and
  returns a boolean (or any other type which will be treated as boolean).

  This function is useful when composed with `star/0` and `some/0`

  > Note:  
  > In terms of functional programming, such conditional lenses are called prisms

  ## Example

      iex> import Pathex.Lenses; import Pathex
      iex> adminl = filtering(& &1.role == :admin)
      iex> {:ok, %{name: "Name", role: :admin}} = Pathex.view(%{name: "Name", role: :admin}, adminl)
      iex> :error = Pathex.view(%{role: :user}, adminl)

      iex> import Pathex.Lenses; import Pathex
      iex> dots2d = [{1, 1}, {1, 5}, {3, 0}, {4, 3}]
      iex> higher_than_2 = filtering(fn {_x, y} -> y > 2 end)
      iex> {:ok, [{1, 5}, {4, 3}]} = Pathex.view(dots2d, star() ~> higher_than_2)
  """
  @doc export: true
  @spec filtering((any() -> boolean())) :: Pathex.t(any(), any())
  def filtering(predicate), do: Filtering.filtering(predicate)
end
