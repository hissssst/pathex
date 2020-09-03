defmodule Pathex.Common do

  @moduledoc """
  Util functions for working with AST
  """

  @typep context :: atom() | nil

  @spec update_variables(Macro.t(), (Macro.t() -> Macro.t()), context) :: Macro.t()
  def update_variables(ast, func, context \\ nil) when is_function(func, 1) do
    Macro.postwalk(ast, fn
      {n, c, ^context} = v when is_atom(n) and is_list(c) ->
        func.(v)
      other ->
        other
    end)
  end

  @spec detect_variables(Macro.t(), context()) :: {Macro.t(), [{atom(), list(), context()}]}
  def detect_variables(ast, context \\ nil) do
    Macro.prewalk(ast, [], fn
      {name, ctx, ^context} = var, acc when is_atom(name) and is_list(ctx) ->
        {var, [var | acc]}

      other, acc ->
        {other, acc}
    end)
  end

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
