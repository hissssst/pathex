defmodule Pathex.Common do
  @moduledoc """
  Util functions for working with AST in Pathex
  Shared among all Pathex projects
  """

  defguard is_var(t)
           when is_tuple(t) and
                  tuple_size(t) == 3 and
                  is_atom(:erlang.element(1, t)) and
                  is_list(:erlang.element(2, t)) and
                  (is_atom(:erlang.element(3, t)) or
                     is_nil(:erlang.element(3, t)))

  @typep context :: atom() | nil

  @doc """
  Creates clause which matches `index`-th element in list
  with `inner` variable
  """
  @spec list_match(non_neg_integer(), Macro.t()) :: Macro.t()
  def list_match(index, inner \\ {:x, [], Elixir})

  def list_match(0, inner) do
    quote(do: [unquote(inner) | _])
  end

  def list_match(index, inner) do
    unders = Enum.map(1..index, fn _ -> {:_, [], Elixir} end)

    quote generated: true do
      [unquote_splicing(unders), unquote(inner) | _]
    end
  end

  @doc """
  Pinns variable for matchings
  """
  @spec pin(Macro.t()) :: Macro.t()
  def pin(ast) when is_var(ast) do
    quote(do: ^unquote(ast))
  end

  def pin(ast), do: ast

  @doc """
  Creates `case` from list of clauses
  """
  @spec to_case([Macro.t()]) :: Macro.t()
  def to_case(clauses) do
    quote generated: true do
      case(do: [unquote_splicing(clauses)])
    end
  end

  @doc """
  This functions puts `generated: true` flag in meta for every node in AST
  to avoid raising errors for dead code and stuff
  """
  @spec set_generated(Macro.t()) :: Macro.t()
  def set_generated(ast) do
    Macro.prewalk(ast, fn item ->
      Macro.update_meta(item, &Keyword.put(&1, :generated, true))
    end)
  end

  # @doc """
  # Traverses AST and updates all variables in it
  # """
  # @spec update_variables(Macro.t(), (Macro.t() -> Macro.t()), context) :: Macro.t()
  # def update_variables(ast, func, context \\ nil) when is_function(func, 1) do
  #   Macro.postwalk(ast, fn
  #     {n, c, ^context} = v when is_atom(n) and is_list(c) ->
  #       func.(v)

  #     other ->
  #       other
  #   end)
  # end

  # @doc """
  # Traverses AST and detects all variables in it
  # """
  # @spec detect_variables(Macro.t(), context()) :: [{atom(), list(), context()}]
  # def detect_variables(ast, context \\ nil) do
  #   Macro.prewalk(ast, [], fn
  #     {name, ctx, ^context} = var, acc when is_atom(name) and is_list(ctx) ->
  #       {var, [var | acc]}

  #     other, acc ->
  #       {other, acc}
  #   end)
  #   |> elem(1)
  # end

end
