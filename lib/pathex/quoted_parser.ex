defmodule Pathex.QuotedParser do
  # Utils module for parsing paths created with `Pathex.path/2`
  @moduledoc false

  import Pathex.Common, only: [is_var: 1]
  alias Pathex.Operations

  @spec parse(Macro.t(), Macro.Env.t(), Pathex.mod()) :: {[Macro.t()], Pathex.Combination.t()}
  def parse(quoted, env, mod) do
    {binds, combination} =
      quoted
      |> parse_composition(:/)
      |> Enum.map(&Macro.expand(&1, env))
      |> Enum.map(&detect_quoted/1)
      |> Enum.unzip()

    case Operations.filter_combination(combination, mod) do
      {:ok, combination} ->
        binds = Enum.reject(binds, &is_nil/1)
        {binds, combination}

      {:error, reason} ->
        raise CompileError,
          line: env.line,
          file: env.file,
          description: "The step is filtered by specified modifier. " <> reason
    end
  end

  @doc """
  Parses chained binary operator call into list of operands
  For example:
      iex> quoted = quote(do: 1 ~> 2 ~> 3)
      iex> parse_composition(quote, :"~>")
      [1, 2, 3]
  """
  @spec parse_composition(Macro.t(), atom()) :: [Macro.t()]
  def parse_composition({symbol, _, [l, r]}, symbol) do
    parse_composition(l, symbol) ++ parse_composition(r, symbol)
  end

  def parse_composition(other, _symbol), do: [other]

  @spec detect_quoted(Macro.t()) :: {Macro.t() | nil, Pathex.Combination.path()}
  defp detect_quoted({:"::", _, [value, types]}) do
    {bind, variants} = detect_quoted(value)

    variants =
      variants
      |> Keyword.take(List.wrap(types))
      |> case do
        [] ->
          raise ArgumentError,
                "You can't annotate #{Macro.to_string(value)} with type #{inspect(types)}"

        pairs ->
          pairs
      end

    {bind, variants}
  end

  defp detect_quoted(var) when is_var(var) do
    {nil, [map: var, keyword: var, list: var, tuple: var]}
  end

  defp detect_quoted(key) when is_atom(key) do
    {nil, [map: key, keyword: key]}
  end

  defp detect_quoted(key) when is_integer(key) do
    {nil, [map: key, list: key, tuple: key]}
  end

  defp detect_quoted(other) do
    if Macro.quoted_literal?(other) do
      {nil, [map: other]}
    else
      var = {:variable, [], :"pathex_context_#{:erlang.unique_integer([:positive])}"}
      bind = quote(do: unquote(var) = unquote(other))
      {bind, detect_type(other, var)}
    end
  end

  # Note that only special forms are here because we can't make any assumptions about
  # operators and stuff, because they can be overloaded with import Kernel, except: ...
  @map_builtins ~w[%{} {} <<>> fn quote __ENV__ __STACKTRACE__ __DIR__ __CALLER__ &]a
  defp detect_type({builtin, _, args}, var) when builtin in @map_builtins do
    if Macro.special_form?(builtin, length(args)) do
      [map: var]
    else
      [map: var, keyword: var, list: var, tuple: var]
    end
  end

  @atom_builtins ~w[__MODULE__ require]a
  defp detect_type({builtin, _, args}, var) when builtin in @atom_builtins do
    if Macro.special_form?(builtin, length(args)) do
      [map: var, keyword: var]
    else
      [map: var, keyword: var, list: var, tuple: var]
    end
  end

  defp detect_type({:^, _, _}, _) do
    raise ArgumentError, "You can't use pin (^) in paths"
  end

  defp detect_type({_, _}, var) do
    [map: var]
  end

  defp detect_type(l, var) when is_list(l) do
    [map: var]
  end

  defp detect_type(_, var) do
    [map: var, keyword: var, list: var, tuple: var]
  end
end
