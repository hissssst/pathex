defmodule Pathex.Lenses.Recur do
  @moduledoc """
  > See `Pathex.Lenses.Recur.recur/1` documentation.
  """

  @compile {:inline, do_recurl: 3, on_error: 2}

  @doc """
  This function creates a lens which is a recursive version of `lens`  

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

  But there are few things you need to keep in mind when using this function

  1. It performs depth-first traversal  
  For example

      iex> import Pathex; import Pathex.Lenses.Recur
      iex> xlens = path(:x)

      iex> 1 == view!(%{x: %{x: 1}}, xlens)
      iex> %{x: 1} != view!(%{x: %{x: 1}}, xlens)

  2. Self-referencing paths create loops  
  For example

      iex> import Pathex; import Pathex.Lenses; import Pathex.Lenses.Recur
      iex> id = matching(_)

      iex> Pathex.view(%{}, recur(id))
      # And you get a loop here
  """
  @doc export: true
  @spec recur(Pathex.t()) :: Pathex.t()
  def recur(lens) when is_function(lens, 2) do
    fn
      :delete, {s} ->
        with :error <- lens.(:update, {s, &recur(lens).(:delete, {&1})}) do
          lens.(:delete, {s})
        end

      :inspect, _ ->
        "recur(#{lens.(:inspect, [])})"

      op, t ->
        lens.(op, update_argtuple(lens, op, t))
    end
  end

  # Helpers

  defp update_argtuple(lens, op, {s, f}) do
    {s, &do_recurl(lens, op, {&1, f})}
  end

  defp update_argtuple(lens, :force_update, {s, f, d}) do
    {s, &do_recurl(lens, :force_update, {&1, f, d}), d}
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

  def prerecur(lens) when is_function(lens, 2) do
    fn
      :view, {s, f} ->
        case lens.(:view, {s, f}) do
          {:ok, res} ->
            prerecur(lens).(:view, {res, f})

          :error ->
            f.(s)
        end
    end
  end

  defp pre_update_argtuple(lens, op, {s, f}) do
    {s, & do_prerecurl(lens, op, {&1, f})}
  end

  defp do_prerecurl(lens, op, {s, f}) do
    case lens.(op, {s, f}) do
      {:ok, res} ->
        f.(res)

      :error ->
        f.(s)
    end
  end
end
