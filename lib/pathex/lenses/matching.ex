defmodule Pathex.Lenses.Matching do
  # Private module for `matching(pattern)` lens
  # > see `Pathex.Lenses.matching/1` documentation
  @moduledoc false

  @doc export: true
  defmacro matching(condition) do
    matching_func(condition)
  end

  import Macro, only: [escape: 1]

  # This case is just an optimization for `id/0`-like lens
  @spec matching_func(Macro.t()) :: Macro.t()
  def matching_func({:_, meta, ctx}) when is_list(meta) and (is_nil(ctx) or is_atom(ctx)) do
    quote do
      fn
        :inspect, _ -> {:matching, [], [{:_, [], nil}]}
        _, x -> :erlang.element(2, x).(:erlang.element(1, x))
      end
    end
  end

  def matching_func({:when, _, [pattern, condition]} = ast) do
    quote do
      fn
        op, {unquote(pattern) = x, func}
        when op in ~w[update view delete]a and unquote(condition) ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} when unquote(condition) ->
          func.(x)

        :force_update, {_x, func, default} ->
          {:ok, default}

        :inspect, _ ->
          {:matching, [], [unquote(unescape_pins(escape(ast)))]}

        op, _ when op in ~w[delete view update force_update]a ->
          :error
      end
    end
  end

  def matching_func(pattern) do
    quote do
      fn
        op, {unquote(pattern) = x, func} when op in ~w[update view delete]a ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} ->
          func.(x)

        :force_update, {_x, func, default} ->
          {:ok, default}

        :inspect, _ ->
          {:matching, [], [unquote(unescape_pins(escape(pattern)))]}

        op, _ when op in ~w[delete view update force_update]a ->
          :error
      end
    end
  end

  defp unescape_pins(ast) do
    Macro.prewalk(ast, fn
      {:{}, _, [:^, _, [{:{}, _, [var, meta, ctx]}]]} -> {var, meta, ctx}
      other -> other
    end)
  end
end
