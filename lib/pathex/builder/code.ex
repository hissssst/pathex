defmodule Pathex.Builder.Code do

  @moduledoc """
  Structure for working with closures as ASTs
  ### Fields
  * vars - list of variables/arguments
  * code - body of a closure
  """

  @enforce_keys [:code]

  defstruct [
    vars: [],
  ] ++ @enforce_keys

  @type code_type :: :one_arg_pipe

  @type t :: %__MODULE__{
    vars: [{atom(), list(), atom() | nil}] | [],
    code: Macro.t(),
  }

  @spec to_fn(t()) :: Macro.t()
  def to_fn(%__MODULE__{vars: vars, code: code}) do
    quote generated: true do
      fn unquote_splicing(vars) ->
        unquote(code)
      end
    end
  end

  @spec to_def(t(), atom()) :: Macro.t()
  def to_def(%__MODULE__{vars: vars, code: code}, name) do
    quote generated: true do
      def unquote(name)(unquote_splicing(vars)) do
        unquote(code)
      end
    end
  end

  @spec multiple_to_fn([{atom(), t()}]) :: Macro.t()
  def multiple_to_fn(codes) do
    cases = Enum.flat_map(codes, fn {key, %{vars: vars, code: code}} ->
      quote generated: true do
        unquote(key), {unquote_splicing(vars)} -> unquote(code)
      end
    end)

    {:fn, [], cases}
  end

  @spec new_one_arg_pipe(Macro.t()) :: t()
  def new_one_arg_pipe(code) do
    x = {:x, [], Elixir}
    code = quote(do: unquote(x) |> unquote(code))
    %__MODULE__{vars: [x], code: code}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{vars: vars, code: code}, opts) do
      code = Macro.to_string(code)
      vars = Enum.map(vars, & elem(&1, 0))
      concat(["#Pathex.Builder.Code<", to_doc(vars, opts), "\n", code, "\n>"])
    end

  end

end
