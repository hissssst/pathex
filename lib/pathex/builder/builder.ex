defmodule Pathex.Builder do

  @moduledoc """
  Module for building combinations into path-closures
  """

  alias Pathex.Builder.Code
  alias Pathex.Builder.Composition
  alias Pathex.Operations

  # Formatting here looks really bad but what can I do...
  alias __MODULE__.{
    ForceUpdater, MatchableViewer, SimpleViewer, SimpleUpdater
  }

  @type t :: ForceUpdater
  | MatchableViewer
  | SimpleViewer
  | SimpleUpdater

  # Behaviour

  @callback build(Pathex.Combination.t()) :: Pathex.Builder.Code.t()

  # API functions

  @doc """
  This function creates quoted fn-closure from passed
  combination and operations

  Closure has two arguments: operation name and tuple or actual arguments

  It will look like
      iex> fn
        :view, {struct} -> ...
        :update, {struct, fun} -> ...
        ...
      end
  """
  @spec build(Pathex.Combination.t(), Operations.t()) :: Macro.t()
  def build(combination, operations) do
    operations
    |> Enum.map(fn {key, builder} ->
      {key, apply(builder, :build, [combination])}
    end)
    |> Code.multiple_to_fn()
  end

  @doc """
  This function creates quoted fn-closure from passed
  combination and builder

  Closure has as much arguments as specified builder creates
  """
  @spec build_only(Pathex.Combination.t(), t()) :: Macro.t()
  def build_only(combination, builder) do
    combination
    |> builder.build()
    |> Code.to_fn()
  end

  @spec build_composition([Macro.t()], atom()) :: Macro.t()
  def build_composition(items, :"&&&") do
    {binds, vars} = bind_items(items)
    func =
      vars
      |> Composition.And.build()
      |> Code.multiple_to_fn()
    quote do
      unquote_splicing(binds)
      unquote(func)
    end
  end

  @spec bind_items([Macro.t()]) :: {[Macro.t()], [Macro.t()]}
  defp bind_items(items) do
    {binds, vars, _} =
      Enum.reduce(items, {[], [], 0}, fn item, {binds, vars, idx} ->
        var = {:"variable_#{idx}", [], Elixir}
        {[quote(do: unquote(var) = unquote(item)) | binds], [var | vars], idx + 1}
      end)
    {Enum.reverse(binds), Enum.reverse(vars)}
  end

end
