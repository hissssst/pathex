defmodule Pathex.QuotedParser do

  @spec parse(Macro.t(), Macro.Env.t()) :: Pathex.Combination.t()
  def parse(quoted, env) do
    quoted
    |> parse_quoted()
    |> Enum.map(&Macro.expand(&1, env))
    |> Enum.map(&detect_quoted/1)
  end

  defp parse_quoted({:/, _, args}) do
    Enum.flat_map(args, &parse_quoted/1)
  end
  defp parse_quoted(x), do: [x]

  defp detect_quoted({name, ctx, nil} = var) when is_atom(name) and is_list(ctx) do
    [map: var, keyword: var, list: var, tuple: var]
  end
  defp detect_quoted(key) when is_atom(key) do
    [map: key, keyword: key]
  end
  defp detect_quoted(key) when is_integer(key) do
    [map: key, list: key, tuple: key]
  end
  defp detect_quoted(other) do
    [map: other]
  end

end
