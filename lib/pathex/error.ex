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
    inspected = path.(:inspect, []) |> :erlang.iolist_to_binary()

    message = """

      #{IO.ANSI.white()}#{message}

        Path:      #{IO.ANSI.cyan()}#{inspected}#{IO.ANSI.white()}

        Structure: #{IO.ANSI.cyan()}#{inspect(structure, pretty: true)}#{IO.ANSI.reset()}
    """

    {%{error | message: message}, stacktrace}
  end
end
