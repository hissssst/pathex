defmodule Pathex.Error do
  @moduledoc """
  Simple exception for bang! functions (like `Pathex.view!/2`) errors.

  > Note:  
  > Some new field may be added in the future
  """

  defexception [:message, :op, :path, :structure]

  @type t :: %__MODULE__{
          message: String.t(),
          op: atom(),
          path: Pathex.t(),
          structure: Pathex.pathex_compatible_structure()
        }

  @impl true
  def blame(%{message: message, path: path, structure: structure} = error, stacktrace) do
    inspected_path =
      path.(:inspect, [])
      |> Macro.to_string()
      |> maybe_format()
      |> IO.iodata_to_binary()
      |> String.replace("\n", "\n               ")

    inspected_structure =
      structure
      |> inspect(pretty: true)
      |> maybe_format()
      |> IO.iodata_to_binary()
      |> String.replace("\n", "\n               ")

    message = """

      #{IO.ANSI.white()}#{message}

        Path:      #{IO.ANSI.cyan()}#{inspected_path}#{IO.ANSI.white()}

        Structure: #{IO.ANSI.cyan()}#{inspected_structure}#{IO.ANSI.reset()}
    """

    {%{error | message: message}, stacktrace}
  end

  defp maybe_format(string) do
    Code.format_string!(string, line_length: 80)
  rescue
    _ -> string
  end
end
