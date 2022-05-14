defmodule Pathex.Builder.Composition do
  # Behaviour for building quoted composition-closures of
  # multiple paths
  @moduledoc false

  @doc """
  Builds composition of path-closure specified as
  quoted variables in input list
  """
  @callback build([Macro.t()]) :: [{Pathex.Operations.name(), Pathex.Builder.Code.t()}]

  alias Pathex.Builder.Code

  @doc """
  Helper function for building inspect clause for binary operators
  """
  @spec build_inspect([Macro.t()], atom() | String.t()) :: Code.t()
  def build_inspect(items, operator) do
    items
    |> Enum.map(&call_inspect/1)
    |> Enum.reduce(fn r, l -> {operator, [], [l, r]} end)
    |> Macro.escape(prune_metadata: true)
    |> Macro.prewalk(&unescape/1)
    |> Code.new([])
  end

  defp call_inspect(path) do
    quote(do: unquote(path).(:inspect, []))
  end

  defp unescape(
         {:{}, _,
          [
            {:{}, _, [:., _, [{:{}, _, [name, meta, context]}]]},
            _,
            [:inspect, _]
          ]}
       )
       when is_atom(name) and is_atom(context) do
    var = {name, meta, context}
    quote(do: unquote(var).(:inspect, []))
  end

  defp unescape(other), do: other
end
