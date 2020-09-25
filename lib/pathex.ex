defmodule Pathex do

  @moduledoc """
  This module contains macroses to be used by user

  Any macro here belongs to one of two categories:
  1) Macro which creates path closure (`sigil_P/2`, `path/2`, `~>/2`)
  2) Macro which uses path closure as path (`over/3`, `set/3`, `view/2`, etc.)

  Path closure is a closure which takes two arguments:
  1) `Atom.t()` with operaion name
  2) `Tuple.t()` of arguments of this operation
  """

  alias Pathex.Builder
  alias Pathex.Operations
  alias Pathex.Parser
  alias Pathex.QuotedParser

  import Pathex.Common, only: [is_var: 1]

  @type struct_type :: :map | :keyword | :list | :tuple
  @type key_type :: :integer | :viewom | :binary

  @type path :: [{struct_type(), any()}]

  @type el_structure :: map() | list() | Keyword.t() | tuple()

  @type result :: {:ok, any()} | {:error, any()} | :error
  @type t :: (
    Operations.name(),
    {el_structure()} | {el_structure(), any()} | {el_structure(), (any() -> any())}
  -> result())

  @type mod :: :map | :json | :naive

  @doc """
  Macro of three arguments which applies given function
  for item in the given path of given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> inc = fn x -> x + 1 end
      iex> {:ok, [0, %{x: 9}]} = over x / :x, [0, %{x: 8}], inc
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [2, [2]]}} = over p, %{"hey" => [1, [2]]}, inc
  """
  defmacro over(path, struct, func) do
    gen(path, :update, [struct, func], __CALLER__)
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = set x / :x, [0, %{x: 8}], 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [123, [2]]}} = set p, %{"hey" => [1, [2]]}, 123
  """
  defmacro set(path, struct, value) do
    gen(path, :update, [struct, quote(do: fn _ -> unquote(value) end)], __CALLER__)
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = force_set x / :x, [0, %{x: 8}], 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_set p, %{}, 1
  """
  defmacro force_set(path, struct, value) do
    gen(path, :force_update, [struct, quote(do: fn _ -> unquote(value) end), value], __CALLER__)
  end

  @doc """
  Macro of four arguments which applies given function
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown and inserts default value

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: {:xxx, 8}}]} = force_over(x / :x, [0, %{x: 8}], & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_over(p, %{}, fn x -> x + 1 end, 1)

  Note:
      Default "default" value is nil
  """
  defmacro force_over(path, struct, func, value \\ nil) do
    gen(path, :force_update, [struct, func, value], __CALLER__)
  end

  @doc """
  Macro returns function applyed to the value in the path
  or error

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, 9} = at x / :x, [0, %{x: 8}], fn x -> x + 1 end
      iex> p = path "hey" / 0
      iex> {:ok, {:here, 9}} = at(p, %{"hey" => {9, -9}}, & {:here, &1})
  """
  defmacro at(path, struct, func) do
    gen(path, :view, [struct, func], __CALLER__)
  end

  @doc """
  Macro gets the value in the given path of the given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, 8} = view x / :x, [0, %{x: 8}]
      iex> p = path "hey" / 0
      iex> {:ok, 9} = view p, %{"hey" => {9, -9}}
  """
  defmacro view(path, struct) do
    gen(path, :view, [struct, quote(do: fn x -> x end)], __CALLER__)
  end

  @doc """
  Sigil for paths. Has only two modes:
  `naive` (default) and `json`.
  Naive paths should look like `~P["string"/:viewom/1]`
  Json paths should look like `~P[string/this_one_is_too/1/0]`
  """
  defmacro sigil_P({_, _, [string]}, mod) do
    mod = detect_mod(mod)
    string
    |> Parser.parse(mod)
    |> Builder.build(Operations.from_mod(mod))
  end

  @doc """
  Creates path for given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
      iex> structure = [0, [atom: %{"string" => %{{"tuple?"} => %{1 => 2}}}]]
      iex> {:ok, 2} = view mypath, structure
  """
  defmacro path(quoted, mod \\ 'naive') do
    mod = detect_mod(mod)
    quoted
    |> QuotedParser.parse(__CALLER__, mod)
    |> Builder.build(Operations.from_mod(mod))
  end

  @doc """
  Creates composition of two paths

  Example:
      iex> require Pathex; import Pathex
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> composed_path = p1 ~> p2
      iex> {:ok, 1} = view composed_path, %{x: [y: [a: [a: 0, b: 1]]]}
  """
  defmacro a ~> b do
    quote generated: true do
      fn
        :view, arg ->
          with {:ok, res} <- unquote(a).(:view, arg) do
            unquote(b).(:view, {res, fn x -> x end})
          end

        :force_update, {struct, function, value} ->
          val =
            case unquote(a).(:view, {struct, fn x -> x end}) do
              :error       -> %{}
              {:ok, other} -> other
            end
          {:ok, val} = unquote(b).(:force_update, {val, function, value})
          unquote(a).(:force_update, {struct, fn _ -> val end, val})

        :update, {target, func} ->
          unquote(a).(:update, {target, fn inner ->
            unquote(b).(:update, {inner, func})
            |> case do
              {:ok, v} -> v
              :error   -> throw :path_not_found
            end
          end})
      end
    end
  end

  # Helper for generating code for path operation
  defp gen(path, op, args, _caller) when is_var(path) do
    quote generated: true do
      unquote(path).(unquote(op), {unquote_splicing(args)})
    end
  end
  defp gen(path, op, args, caller) do
    path_func = build_only(path, op, caller)
    quote generated: true do
      unquote(path_func).(unquote_splicing(args))
    end
  end

  # Helper for detecting mod
  defp detect_mod(mod) when mod in ~w(naive map json)a, do: mod
  defp detect_mod(str) when is_binary(str), do: detect_mod('#{str}')
  defp detect_mod('json'), do: :json
  defp detect_mod('map'), do: :map
  defp detect_mod(_), do: :naive

  defp build_only(path, opname, caller, mod \\ :naive) do
    %{^opname => builder} = Operations.from_mod(mod)
    case Macro.prewalk(path, & Macro.expand(&1, caller)) do
      {{:".", _, [__MODULE__, :path]}, _, args} ->
        args

      {:path, meta, args} ->
        __MODULE__ = Keyword.fetch!(meta, :import)
        args

      args ->
        args
    end
    |> QuotedParser.parse(caller, mod)
    |> Builder.build_only(builder)
  end

end
