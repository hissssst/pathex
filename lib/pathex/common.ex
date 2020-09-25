defmodule Pathex.Common do

  @moduledoc """
  Util functions for working with AST
  """

  defguard is_var(t) when is_tuple(t)
    and tuple_size(t) == 3
    and is_atom(:erlang.element(1, t))
    and is_list(:erlang.element(2, t))
    and (is_atom(:erlang.element(3, t))
    or is_nil(:erlang.element(3, t)))

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

  @spec detect_variables(Macro.t(), context()) :: [{atom(), list(), context()}]
  def detect_variables(ast, context \\ nil) do
    Macro.prewalk(ast, [], fn
      {name, ctx, ^context} = var, acc when is_atom(name) and is_list(ctx) ->
        {var, [var | acc]}

      other, acc ->
        {other, acc}
    end)
    |> elem(1)
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
  def pin(ast) when is_var(ast) do
    quote(do: ^unquote(ast))
  end
  def pin(ast), do: ast

end
