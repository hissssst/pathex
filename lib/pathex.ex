defmodule Pathex do

  @type struct_type :: :map | :keyword | :list | :tuple
  @type key_type :: :integer | :atom | :binary

  @type path :: [{struct_type(), any()}]

  defp detect_mod(mod), do: mod

  defmacro sigil_P({_, _, [string]}, mod) do
    IO.inspect string, label: :string
    IO.inspect mod, label: :mod

    mod = detect_mod(mod)

    string
    |> Pathex.Parser.parse(mod)
    |> Pathex.Combination.from_suggested_path()
    |> Pathex.Builder.build(mod)
    |> Pathex.Builder.Code.to_fn()
  end

end
