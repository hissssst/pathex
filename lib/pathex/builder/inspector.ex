defmodule Pathex.Builder.Inspector do
  # Builder for inspect feature
  @moduledoc false

  @behaviour Pathex.Builder
  alias Pathex.Builder.Code
  alias Pathex.Common

  @impl Pathex.Builder
  def build(combination) do
    slashed =
      combination
      |> Enum.map(fn [{_type, key} | _others] ->
        key
      end)
      |> Enum.reduce(fn r, l -> quote(do: unquote(l) / unquote(r)) end)

    quote(do: path(unquote(slashed)))
    |> Common.safe_drop_meta()
    |> Macro.escape()
    |> Macro.prewalk(&unescape/1)
    |> Code.new([])
  end

  defp unescape({:{}, _meta, [name, meta, context]}) when is_atom(name) and is_atom(context) do
    {name, meta, context}
  end

  defp unescape(other), do: other
end
