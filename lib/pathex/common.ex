defmodule Pathex.Common do

  @moduledoc """
  Util functions for working with AST
  """

  def update_variables(ast, func, context \\ nil) when is_function(func, 1) do
    Macro.postwalk(ast, fn
      {n, c, ^context} = v when is_atom(n) and is_list(c) ->
        func.(v)
      other ->
        other
    end)
  end

  def detect_variables(ast, context \\ nil) do
    Macro.prewalk(ast, [], fn
      {name, ctx, ^context} = var, acc when is_atom(name) and is_list(ctx) ->
        {var, [var | acc]}

      other, acc ->
        {other, acc}
    end)
  end

end
