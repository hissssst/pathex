defmodule Pathex.Builder.Code do

  @enforce_keys [:code]

  defstruct [
    vars: [],
    type: nil
  ] ++ @enforce_keys

  @type code_type :: :one_arg_pipe

  @type t :: %__MODULE__{
    vars: [{atom(), list(), Elixir}] | [],
    code: Macro.t(),
    type: nil | code_type()
  }

  def to_fn(%__MODULE__{type: :one_arg_pipe, code: code}) do
    quote do
      fn x ->
        x |> unquote(code)
      end
    end
  end

  def to_def(%__MODULE__{type: :one_arg_pipe, code: code}, name) do
    quote do
      def unquote(name)(x) do
        x |> unquote(code)
      end
    end
  end

  def new_one_arg_pipe(code) do
    %__MODULE__{type: :one_arg_pipe, code: code}
  end

end
