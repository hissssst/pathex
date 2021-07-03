defmodule Pathex.Lenses.Recur do

  @moduledoc """
  > see `Pathex.Lenses.Recur.recur/1` documentation
  """

  @compile {:inline, do_recurl: 3, on_error: 2}

  #defguardp is_coll(x) when is_list(x) or is_tuple(x) or is_map(x)

  @doc """
  This is function which makes you lens recursive
  Simple example:

      iex> import Pathex; import Pathex.Lenses.Recur
      iex> # You have simple lens
      iex> xlens = path(:x)

      iex> # Which works like you'd expect
      iex> {:ok, 1} = Pathex.view(%{x: 1}, lensx)

      iex> # But then you need to take data which is nested deeply like
      iex> nested = %{x: %{x: %{x: %{x: %{x: 1}}}}}

      iex> # You can make this lens a recursive one
      iex> recur_xlens = recur(xlens)

      iex> # It'll be able to view, update and force_update all nested values
      iex> {:ok, 1} = Pathex.view(nested, recur_xlens)
      iex> %{x: %{x: %{x: %{x: %{x: 2}}}}} = Pathex.set!(nested, recur_xlens, 2)
      iex> %{x: %{x: %{x: %{x: %{x: 2}}}}} = Pathex.force_set!(nested, recur_xlens, 2)
  """
  def recur(lens) when is_function(lens, 2) do
    fn op, t -> lens.(op, update_argtuple(lens, op, t)) end
  end

  # Helpers

  defp update_argtuple(lens, op, {s, f}) do
    {s, & do_recurl(lens, op, {&1, f})}
  end
  defp update_argtuple(lens, :force_update, {s, f, d}) do
    {s, & do_recurl(lens, :force_update, {&1, f, d}), d}
  end

  defp do_recurl(lens, op, t) do
    with :error <- lens.(op, update_argtuple(lens, op, t)) do
      on_error(op, t)
    end
  end

  defp on_error(op, {term, func}) when op in ~w[view update]a do
    func.(term)
  end
  defp on_error(:force_update, {term, func, default}) do
    with :error <- func.(term) do
      {:ok, default}
    end
  end

end
