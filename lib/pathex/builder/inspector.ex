defmodule Pathex.Builder.Inspector do
  # Builder for inspect feature
  @moduledoc false

  @behaviour Pathex.Builder
  alias Pathex.Builder.Code

  @impl Pathex.Builder
  def build(combination) do
    slashed =
      combination
      |> Enum.map(fn [{_type, key} | _others] ->
        key
      end)
      |> Enum.reduce(fn r, l -> quote(do: unquote(l) / unquote(r)) end)

    quote(do: path(unquote(slashed)))
    |> Macro.escape()
    |> Macro.postwalk(&unescape/1)
    |> Code.new([])
  end

  defp unescape({:{}, _meta, [name, meta, context]}) when is_atom(name) and is_list(meta) and is_atom(context) do
    quote do
      try do
        Macro.escape unquote({name, meta, context})
      rescue
        _ -> unquote({name, meta, context})
      end
    end
  end

  defp unescape(other), do: other
end
