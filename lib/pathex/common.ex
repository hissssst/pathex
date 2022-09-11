defmodule Pathex.Common do
  # Util functions for working with AST in Pathex
  # Shared among all Pathex projects
  @moduledoc false

  @doc """
  Guard which checks if given AST contains a variable
  """
  defguard is_var(t)
           when is_tuple(t) and
                  tuple_size(t) == 3 and
                  is_atom(:erlang.element(1, t)) and
                  is_list(:erlang.element(2, t)) and
                  (is_atom(:erlang.element(3, t)) or
                     is_nil(:erlang.element(3, t)))

  @doc """
  Creates clause which matches `index`-th element in list
  with `inner` variable
  """
  @spec list_match(integer(), Macro.t()) :: Macro.t()
  def list_match(index, inner \\ {:x, [], Elixir})

  def list_match(0, inner) do
    quote(do: [unquote(inner) | _])
  end

  def list_match(index, inner) when index > 0 do
    underscores = List.duplicate({:_, [], Elixir}, index)

    quote generated: true do
      [unquote_splicing(underscores), unquote(inner) | _]
    end
  end

  def list_match(index, inner) when index < 0 do
    index = abs(index) - 1
    underscores = List.duplicate({:_, [], Elixir}, index)

    List.update_at([inner] ++ underscores, -1, fn x -> quote(do: unquote(x) | _) end)
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
    Macro.prewalk(ast, fn
      var when is_var(var) ->
        var

      item ->
        Macro.update_meta(item, &Keyword.put(&1, :generated, true))
    end)
  end

  @spec safe_drop_meta(Macro.t()) :: Macro.t()
  def safe_drop_meta(ast) do
    Macro.prewalk(ast, fn
      {name, meta, context} = var when is_var(var) ->
        {name, Keyword.take(meta, [:counter]), context}

      {x, _meta, y} ->
        {x, [], y}

      other ->
        other
    end)
  end
end
