defmodule Pathex.Builder do

  @moduledoc """
  Module for building combinations into path-closures
  """

  import Pathex.Common
  alias __MODULE__.{
    Code, ForceSetter, MatchableSelector,
    SimpleSelector, SimpleSetter, UpdateSetter
  }

  # API

  @spec build(Pathex.Combination.t(), Pathex.mod()) :: Macro.t()
  def build(combination, mod) when mod in [:map, :json] do
    [
      get:       MatchableSelector.build(combination),
      set:       SimpleSetter.build(combination),
      force_set: ForceSetter.build(combination),
      update:    UpdateSetter.build(combination)
    ]
    |> Code.multiple_to_fn()
  end
  def build(combination, :naive) do
    [
      get:       SimpleSelector.build(combination),
      set:       SimpleSetter.build(combination),
      force_set: ForceSetter.build(combination),
      update:    UpdateSetter.build(combination)
    ]
    |> Code.multiple_to_fn()
  end

  # Imported helpers

  @spec list_match(non_neg_integer(), Macro.t()) :: Macro.t()
  def list_match(index, inner \\ {:x, [], Elixir})
  def list_match(0, inner) do
    quote(do: [unquote(inner) | _])
  end
  def list_match(index, inner) do
    unders = Enum.map(1..index, fn _ -> {:_, [], Elixir} end)
    quote(do: [unquote_splicing(unders), unquote(inner) | _])
  end

  @spec pin(Macro.t()) :: Macro.t()
  def pin(ast) do
    case detect_variables(ast) do
      {_, []} -> ast
      _ -> quote(do: ^unquote(ast))
    end
  end

end
