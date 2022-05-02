defmodule Pathex.QuotedParser do
  # Utils module for parsing paths created with `Pathex.path/2`
  @moduledoc false

  import Pathex.Common, only: [is_var: 1]
  alias Pathex.Operations

  @spec parse(Macro.t(), Macro.Env.t(), Pathex.mod()) :: Pathex.Combination.t()
  def parse(quoted, env, mod) do
    quoted
    |> parse_composition(:/)
    |> Enum.map(&Macro.expand(&1, env))
    |> Enum.map(&detect_quoted/1)
    |> Operations.filter_combination(mod)
  end

  @doc """
  Parses chained binary operator call into list of operands
  For example:
      iex> quoted = quote(do: 1 ~> 2 ~> 3)
      iex> parse_composition(quote, :"~>")
      [1, 2, 3]
  """
  @spec parse_composition(Macro.t(), atom()) :: [Macro.t()]
  def parse_composition({symbol, _, [l, r]}, symbol) do
    parse_composition(l, symbol) ++ parse_composition(r, symbol)
  end

  def parse_composition(other, _symbol), do: [other]

  @spec detect_quoted(Macro.t()) :: Pathex.Combination.t()
  defp detect_quoted({:"::", _, [value, types]}) do
    value
    |> detect_quoted()
    |> Keyword.take(List.wrap types)
    |> case do
      [] ->
        raise ArgumentError, "You can't annotate #{Macro.to_string value} with type #{inspect types}"

      pairs ->
        pairs
    end
  end

  defp detect_quoted(var) when is_var(var) do
    [map: var, keyword: var, list: var, tuple: var]
  end

  defp detect_quoted(key) when is_atom(key) do
    [map: key, keyword: key]
  end

  defp detect_quoted(key) when is_integer(key) do
    [map: key, list: key, tuple: key]
  end

  defp detect_quoted(other) do
    [map: other]
  end
end
