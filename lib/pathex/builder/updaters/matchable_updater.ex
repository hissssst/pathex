defmodule Pathex.Builder.MatchableUpdater do
  # Updater for matchable structures
  @moduledoc false

  alias Pathex.Combination
  alias Pathex.Common
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  @impl Pathex.Builder
  def build(combination) do
    combination
    |> Combination.to_paths()
    |> Enum.flat_map(&build_for_path/1)
    |> Kernel.++(fallback())
    |> Common.to_case()
    |> wrap_to_code()
  end

  defp build_for_path(path) do
    path = Enum.reverse(path)
    in_var = {:x, [], Elixir}
    out_var = {:y, [], Elixir}

    {pattern, vars} =
      Enum.reduce(path, {in_var, []}, fn
        {:map, key}, {code, vars} ->
          key = Common.pin(key)
          var = {:"x_#{:erlang.unique_integer([:positive])}", [], Elixir}

          code =
            quote do
              %{unquote(key) => unquote(code)} = unquote(var)
            end

          {code, [var | vars]}

        {:list, index}, {code, vars} ->
          tail = {:"x_#{:erlang.unique_integer([:positive])}", [], Elixir}
          {pattern, match_vars} = list_pattern(index, code, tail)

          {pattern, [{tail, match_vars} | vars]}
      end)

    putter =
      path
      |> Enum.zip(Enum.reverse(vars))
      |> Enum.reduce(out_var, fn
        {{:map, key}, var}, code ->
          quote do
            %{unquote(var) | unquote(key) => unquote(code)}
          end

        {{:list, _index}, {tail, matching_vars}}, code ->
          list_body(matching_vars, code, tail)
      end)

    body =
      quote do
        with {:ok, unquote(out_var)} <- unquote(@function_variable).(unquote(in_var)) do
          {:ok, unquote(putter)}
        end
      end

    quote do
      unquote(pattern) -> unquote(body)
    end
  end

  defp list_body(matching_vars, inner, tail) do
    quote(do: [unquote_splicing(matching_vars), unquote(inner) | unquote(tail)])
  end

  defp list_pattern(0, inner, tail) do
    {quote(do: [unquote(inner) | unquote(tail)]), []}
  end

  defp list_pattern(index, inner, tail) do
    ui = :erlang.unique_integer([:positive])
    vars = Enum.map(1..index, fn i -> {:"l_#{ui}_#{i}", [], Elixir} end)

    code =
      quote generated: true do
        [unquote_splicing(vars), unquote(inner) | unquote(tail)]
      end

    {code, vars}
  end

  defp wrap_to_code(code) do
    code =
      quote do
        unquote(@structure_variable) |> unquote(code)
      end

    %Pathex.Builder.Code{code: code, vars: [@structure_variable, @function_variable]}
  end

  defp fallback do
    quote do
      _ -> :error
    end
  end
end
