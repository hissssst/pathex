defmodule Pathex do

  @type struct_type :: :map | :keyword | :list | :tuple
  @type key_type :: :integer | :atom | :binary

  @type path :: [{struct_type(), any()}]

  defp detect_mod(mod), do: mod

  defmacro sigil_P({_, _, [string]}, mod) do
    mod = detect_mod(mod)
    string
    |> Pathex.Parser.parse(mod)
    |> Pathex.Combination.from_suggested_path()
    |> Pathex.Builder.build(mod)
  end

  defmacro path(quoted, mod \\ 'naive') do
    mod = detect_mod(mod)
    quoted
    |> Pathex.QuotedParser.parse(__ENV__)
    |> Pathex.Builder.build(mod)
  end

  defmacro a ~> b do
    quote do
      fn
        :get, arg ->
          with {:ok, res} <- unquote(a).(:get, arg) do
            unquote(b).(:get, {res})
          end

        :set, {target, val} ->
          inner = unquote(a).(:get, {target})
          inner = unquote(b).(:set, {inner, val})
          unquote(a).(:set, {target, inner})
      end
    end
  end

end
