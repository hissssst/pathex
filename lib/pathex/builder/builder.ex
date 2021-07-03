defmodule Pathex.Builder do

  @moduledoc """
  Module for building combinations into path-closures
  """

  alias Pathex.Builder.Code
  alias Pathex.Builder.Composition
  alias Pathex.Operations

  @type t :: module()

  @composition_builders %{
    "&&&": Composition.And,
    "|||": Composition.Or,
    "~>":  Composition.Concat
  }

  # Behaviour

  @doc """
  Implementation takes combination for path-closure and
  returns code structure to be built into some case of
  path-closure
  """
  @callback build(Pathex.Combination.t()) :: Code.t()

  # API functions

  @doc """
  This function creates quoted fn-closure from passed
  combination and operations

  Closure has two arguments: operation name and tuple or actual arguments

  It will look like
      iex> fn
        :view, {struct, fun} -> ...
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

  @doc """
  This function creates quoted path-closure which is a composition
  of multiple quoted paths
  """
  @spec build_composition([Macro.t()], atom(), Macro.Env.t()) :: Macro.t()
  for {composition, builder} <- @composition_builders do
    def build_composition(items, unquote(composition), env) do
      context = :"pathex_context_#{:erlang.unique_integer([:positive])}"
      {binds, vars} = bind_items(items, env, context)
      func =
        vars
        |> unquote(builder).build()
        |> Code.multiple_to_fn()

      quote do
        unquote_splicing(binds)
        unquote(func)
      end
    end
  end

  # Returns bindings for variables which works like
  # quote's bind_quoted
  @spec bind_items(vars :: [Macro.t()], env :: Macro.Env.t(), context :: atom())
  :: {binds :: [Macro.t()], vars :: [Macro.t()]}
  defp bind_items(items, env, context) do
    {binds, vars, _} =
      Enum.reduce(items, {[], [], 0}, fn item, {binds, vars, idx} ->
        var = {:"variable_#{idx}", [], context}
        item = Macro.expand(item, env)
        bind = quote(do: unquote(var) = unquote(item))
        {[bind | binds], [var | vars], idx + 1}
      end)
    {Enum.reverse(binds), Enum.reverse(vars)}
  end

end
