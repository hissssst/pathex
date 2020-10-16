defmodule Pathex.QuotedParser do

  @moduledoc """
  Utils module for parsing paths created with `Pathex.path/2`
  """

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

  @spec parse_composition(Macro.t(), atom()) :: [Macro.t()]
  def parse_composition({symbol, _, [l, r]}, symbol) do
    parse_composition(l, symbol) ++ parse_composition(r, symbol)
  end
  def parse_composition(other, _symbol), do: [other]

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
