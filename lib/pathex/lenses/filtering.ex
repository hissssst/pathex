defmodule Pathex.Lenses.Filtering do
  # Private module for `filtering(condition)` lens
  # > see `Pathex.Lenses.filtering/1` documentation
  @moduledoc false

  @spec filtering((any() -> boolean() | any())) :: Pathex.t()
  def filtering(predicate) do
    fn
      op, {structure, func} when op in ~w[update view delete]a ->
        if(predicate.(structure), do: func.(structure), else: :error)

      :force_update, {structure, func, default} ->
        if(predicate.(structure), do: func.(structure), else: {:ok, default})

      :inspect, _ ->
        {:filtering, [], [inspect(predicate)]}
    end
  end
end
