defmodule Pathex.Builder.Inspector do
  # Builder for inspect feature
  @moduledoc false

  @behaviour Pathex.Builder
  import Pathex.Common, only: [is_var: 1]
  alias Pathex.Builder.Code

  alias Pathex.QuotedParser

  def build(combination) do
    combination
    |> Enum.map(fn [{_type, key} | _others] -> str(key) end)
    |> Enum.reduce(&quote(do: unquote(&2) <> " / " <> unquote(&1)))
    |> then(&quote(do: "path(" <> unquote(&1) <> ")"))
    |> do_relax()
    |> Code.new([])
  end

  @spec str(Inspect.t() | Macro.t()) :: Macro.t() | binary()
  defp str(variable) when is_var(variable) do
    quote(do: inspect(unquote(variable)))
  end

  defp str(other), do: inspect(other)

  # Tries to concat known binaries in compile time
  # Like constant propagation
  @spec do_relax(Macro.t()) :: Macro.t()
  defp do_relax(quoted) do
    quoted
    |> QuotedParser.parse_composition(:"<>")
    |> Enum.reduce([], fn
      first, [] ->
        [first]

      r, [l | head] when is_binary(r) and is_binary(l) ->
        [l <> r | head]

      other, head ->
        [other | head]
    end)
    |> Enum.reduce(fn l, r ->
      quote(do: unquote(l) <> unquote(r))
    end)
  end
end
