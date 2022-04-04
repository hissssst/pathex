defmodule Pathex.Lenses.Filtering do
  # Private module for `filtering(condition)` lens
  # > see `Pathex.Lenses.filtering/1` documentation
  @moduledoc false

  def filtering(predicate) do
    fn
      op, {structure, func} when op in ~w[update view]a ->
        (predicate.(structure) && func.(structure)) || :error

      :force_update, {structure, func, default} ->
        (predicate.(structure) && func.(structure)) || default

      :inspect, _ ->
        "filtering(#{inspect(predicate)})"

      # Can't delete value from self-referencing lens
      :delete, _ ->
        :error
    end
  end
end
