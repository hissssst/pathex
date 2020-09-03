defmodule Pathex.Builder do

  @moduledoc """
  Module for building combinations into path-closures
  """

  alias Pathex.Builder.Code
  alias Pathex.Operations

  # Formatting here looks really bad but what can I do...
  alias __MODULE__.{
    ForceSetter, MatchableSelector, SimpleSelector, SimpleSetter, UpdateSetter
  }

  @type t :: ForceSetter
  | MatchableSelector
  | SimpleSelector
  | SimpleSetter
  | UpdateSetter

  # API functions

  @doc """
  This function creates quoted fn-closure from passed
  combination and operations

  Closure has two arguments: operation name and tuple or actual arguments

  It will look like
      iex> fn
        :get, {struct} -> ...
        :set, {struct, value} -> ...
        ...
      end
  """
  @spec build(Pathex.Combination.t(), Operations.t()) :: Macro.t()
  def build(combination, operations) do
    operations
    |> Enum.map(fn {key, builder} -> {key, builder.build(combination)} end)
    |> Code.multiple_to_fn()
  end

  @doc """
  This function creates quoted fn-closure from passed
  combination and builder

  Closure has as much arguments as specified builder creates
  """
  @spec build_only(Pathex.Combination.t(), t()) :: Macro.t()
  def build_only(combination, builder) do
    builder.build(combination)
    |> Code.to_fn()
  end

end
