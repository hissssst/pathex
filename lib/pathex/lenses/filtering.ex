defmodule Pathex.Lenses.Filtering do
  @moduledoc """
  Private module for `filtering(condition)` lens
  > see `Pathex.Lenses.filtering/1` documentation
  """

  def filtering(predicate) do
    fn
      op, {structure, func} when op in ~w[update view]a ->
        (predicate.(structure) && func.(structure)) || :error

      :force_update, {structure, func, default} ->
        (predicate.(structure) && func.(structure)) || default
    end
  end
end
