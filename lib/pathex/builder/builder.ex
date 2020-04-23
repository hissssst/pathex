defmodule Pathex.Builder do

  import Pathex.Common

  @spec build(Pathex.Combination.t(), charlist()) :: Macro.t()
  def build(combination, mod) when mod in ['map', 'json'] do
    [
      get: __MODULE__.MatchableSelector.build(combination),
      set: __MODULE__.SimpleSetter.build(combination),
      update: __MODULE__.UpdateSetter.build(combination)
    ]
    |> __MODULE__.Code.multiple_to_fn()
  end
  def build(combination, 'naive') do
    [
      get: __MODULE__.SimpleSelector.build(combination),
      set: __MODULE__.SimpleSetter.build(combination),
      update: __MODULE__.UpdateSetter.build(combination)
    ]
    |> __MODULE__.Code.multiple_to_fn()
  end

  def list_match(index, inner \\ {:x, [], Elixir})
  def list_match(0, inner) do
    quote(do: [unquote(inner) | _])
  end
  def list_match(index, inner) do
    unders = Enum.map(1..index, fn _ -> {:_, [], Elixir} end)
    quote(do: [unquote_splicing(unders), unquote(inner) | _])
  end

  def pin(ast) do
    case detect_variables(ast) do
      {_, []} -> ast
      _ -> quote(do: ^unquote(ast))
    end
  end

end
