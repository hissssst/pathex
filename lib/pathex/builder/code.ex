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

  @doc """
  Converts code structure to quoted fn-closure
  """
  @spec to_fn(t()) :: Macro.t()
  def to_fn(%__MODULE__{vars: vars, code: code}) do
    quote generated: true do
      fn unquote_splicing(vars) ->
        unquote(code)
      end
    end
  end

  @doc """
  Converts code structure to quoted def-statement
  """
  @spec to_def(t(), atom()) :: Macro.t()
  def to_def(%__MODULE__{vars: vars, code: code}, name) do
    quote generated: true do
      def unquote(name)(unquote_splicing(vars)) do
        unquote(code)
      end
    end
  end

  @doc """
  Converts code structures to quoted fn-statement with multiple clauses
  """
  @spec multiple_to_fn([{atom(), t()}] | %{atom() => t()}) :: Macro.t()
  def multiple_to_fn(codes) do
    cases = Enum.flat_map(codes, fn {key, %{vars: vars, code: code}} ->
      quote generated: true do
        unquote(key), {unquote_splicing(vars)} -> unquote(code)
      end
    end)

    {:fn, [], cases}
  end

  @doc """
  Converts quoted code with list of quoted vars to
  piped %Code{} with first arg piping into quoted code
  """
  @spec new_arg_pipe(Macro.t(), [Macro.t()]) :: t()
  def new_arg_pipe(code, [arg1 | _] = args) do
    code = quote(do: unquote(arg1) |> unquote(code))
    %__MODULE__{code: code, vars: args}
  end

  @doc """
  Simply creates new Code structure
  """
  @spec new(Macro.t(), [Macro.t()]) :: t()
  def new(code, vars) do
    %__MODULE__{code: code, vars: vars}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{vars: vars, code: code}, opts) do
      code =
        code
        |> Macro.to_string()
        |> Code.format_string!()
        |> IO.iodata_to_binary()

      vars = Enum.map(vars, & elem(&1, 0))
      concat(["#Pathex.Builder.Code<", to_doc(vars, opts), "\n", code, "\n>"])
    end

  end

end
