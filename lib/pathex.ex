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

  defmacro over(path, struct, function) do
    quote generated: true do
      unquote(path).(:update, {unquote(struct), unquote(function)})
    end
  end

  defmacro set(path, struct, value) do
    quote generated: true do
      unquote(path).(:set, {unquote(struct), unquote(value)})
    end
  end

  defmacro view(path, struct) do
    quote generated: true do
      unquote(path).(:get, {unquote(struct)})
    end
  end

  defmacro path(quoted, mod \\ 'naive') do
    mod = detect_mod(mod)
    quoted
    |> Pathex.QuotedParser.parse(__ENV__)
    |> Pathex.Builder.build(mod)
  end

  defmacro a ~> b do
    quote generated: true do
      fn
        :get, arg ->
          with {:ok, res} <- unquote(a).(:get, arg) do
            unquote(b).(:get, {res})
          end

        cmd, {target, arg} ->
          with(
            {:ok, inner} <- unquote(a).(:get, {target}),
            {:ok, inner} <- unquote(b).(cmd, {inner, arg})
          ) do
            unquote(a).(:set, {target, inner})
          end
      end
    end
  end

end
