defmodule Pathex.Lenses.Matching do
  @moduledoc """
  Private module for `matching(pattern)` lens
  > see `Pathex.Lenses.matching/1` documentation
  """

  @doc export: true
  defmacro matching(condition) do
    matching_func(condition)
  end

  # This case is just an optimization for `id/0`-like lens
  def matching_func({:_, meta, ctx}) when is_list(meta) and (is_nil(ctx) or is_atom(ctx)) do
    quote do
      fn
        :delete, _ -> :error
        _, x -> :erlang.element(2, x).(:erlang.element(1, x))
      end
    end
  end

  def matching_func({:when, _, [pattern, condition]}) do
    quote do
      fn
        op, {unquote(pattern) = x, func} when op in ~w[update view]a and unquote(condition) ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} when unquote(condition) ->
          func.(x)

        :force_update, {_x, func, default} ->
          default

        op, _ when op in ~w[delete view update force_update]a ->
          :error
      end
    end
  end

  def matching_func(pattern) do
    quote do
      fn
        op, {unquote(pattern) = x, func} when op in ~w[update view]a ->
          func.(x)

        :force_update, {unquote(pattern) = x, func, default} ->
          func.(x)

        :force_update, {_x, func, default} ->
          default

        op, _ when op in ~w[delete view update force_update]a ->
          :error
      end
    end
  end
end
