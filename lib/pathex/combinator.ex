defmodule Pathex.Combinator do
  @moduledoc """
  Combinator for lenses
  Read `Pathex.Combinator.combine/1` documentation
  """

  @doc """
  This function creates a recursive path from path defined in `path_func`
  Consider this example

      iex> import Pathex; import Pathex.Lenses
      iex> recursive_xpath = combine(fn recursive_xpath ->
      iex>   path(:x)            # Takes by :x key
      iex>   ~> recursive_xpath  # If taken, calls itself
      iex>   ||| matching(_)     # Otherwise returns current structure
      iex> end)
      iex>
      iex> Pathex.view!(%{x: %{x: %{x: %{x: 1}}}}, recursive_xpath)
      1
      iex> Pathex.set!(%{x: %{x: %{x: %{x: 1}}}}, recursive_xpath, 2)
      %{x: %{x: %{x: %{x: 2}}}}

  The second argument of this function specifies the maximum depth. It's infinity be default,
  but you can specify this as any positive integer. It is useful when you're developing lens
  and you're not sure whether the lens will or won't loop.

  For example
  ```elixir
  # Combinator lens with limit
  limited = combine(fn rec -> path(:x) ~> rec end, 100_000)
  :error = Pathex.force_set(%{x: 1}, limited, 123)

  # And this is without limit
  unlimited = combine(fn rec -> path(:x) ~> rec end)
  Pathex.force_set(%{x: 1}, unlimited, 123) # Infinite loop
  ```
  """
  @spec combine((Pathex.t() -> Pathex.t()), pos_integer() | :infinity) :: Pathex.t()
  def combine(path_func, max_depth \\ :infinity)

  def combine(path_func, :infinity) do
    fn
      :inspect, _ ->
        inner = path_func.(inner_rec(path_func)).(:inspect, [])

        quote do
          combine(fn recursive -> unquote(inner) end)
        end

      op, argtuple ->
        path_func.(inner_rec(path_func)).(op, argtuple)
    end
  end

  def combine(path_func, max_depth) when is_integer(max_depth) and max_depth > 0 do
    fn
      :inspect, _ ->
        inner = path_func.(inner_rec(path_func, 1, max_depth)).(:inspect, [])

        quote do
          combine(fn recursive -> unquote(inner) end)
        end

      op, argtuple ->
        path_func.(inner_rec(path_func, 1, max_depth)).(op, argtuple)
    end
  end

  defp inner_rec(path_func, depth, max_depth) when depth <= max_depth do
    fn
      :inspect, _ ->
        {:recursive, [], nil}

      op, argtuple ->
        path_func.(inner_rec(path_func, depth, max_depth)).(op, argtuple)
    end
  end

  defp inner_rec(_, _, _) do
    fn _, _ -> :error end
  end

  defp inner_rec(path_func) do
    fn
      :inspect, _ ->
        {:recursive, [], nil}

      op, argtuple ->
        path_func.(inner_rec(path_func)).(op, argtuple)
    end
  end
end
