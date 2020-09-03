defmodule Pathex do

  @moduledoc """
  This module contains macroses to be used by user

  Any macro here belongs to one of two categories:
  1) Macro which creates path closure (`sigil_P/2`, `path/2`, `~>/2`)
  2) Macro which uses path closure as path (`over/3`, `set/3`, `view/2`)

  Path closure is a closure which takes two arguments:
  1) `Atom.t()` with operaion name
  2) `Tuple.t()` of arguments of this operation
  """

  alias Pathex.Builder
  alias Pathex.Operations
  alias Pathex.Parser
  alias Pathex.QuotedParser

  @type struct_type :: :map | :keyword | :list | :tuple
  @type key_type :: :integer | :atom | :binary

  @type path :: [{struct_type(), any()}]

  @type el_structure :: map() | list() | Keyword.t() | tuple()

  @type result :: {:ok, any()} | {:error, any()} | :error
  @type t :: (
    :get | :set | :update | :force_set,
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
  defmacro over({:"/", _, _} = path, struct, function) do
    path_func = build_only(path, :update, __CALLER__)
    quote generated: true do
      unquote(path_func).(unquote(struct), unquote(function))
    end
  end
  defmacro over(path, struct, function) do
    quote generated: true do
      unquote(path).(:update, {unquote(struct), unquote(function)})
    end
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
  defmacro set({:"/", _, _} = path, struct, value) do
    path_func = build_only(path, :set, __CALLER__)
    quote generated: true do
      unquote(path_func).(unquote(struct), unquote(value))
    end
  end
  defmacro set(path, struct, value) do
    quote generated: true do
      unquote(path).(:set, {unquote(struct), unquote(value)})
    end
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
  defmacro force_set({:"/", _, _} = path, struct, value) do
    path_func = build_only(path, :force_set, __CALLER__)
    quote generated: true do
      unquote(path_func).(unquote(struct), unquote(value))
    end
  end
  defmacro force_set(path, struct, value) do
    quote generated: true do
      unquote(path).(:force_set, {unquote(struct), unquote(value)})
    end
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
  defmacro view({:"/", _, _} = path, struct) do
    path_func = build_only(path, :get, __CALLER__)
    quote generated: true do
      unquote(path_func).(unquote(struct))
    end
  end
  defmacro view(path, struct) do
    quote generated: true do
      unquote(path).(:get, {unquote(struct)})
    end
  end

  @doc """
  Sigil for paths. Has only two modes:
  `naive` (default) and `json`.
  Naive paths should look like `~P["string"/:atom/1]`
  Json paths should look like `~P[string/this_one_is_too/1/0]`
  """
  defmacro sigil_P({_, _, [string]}, mod) do
    mod = detect_mod(mod)
    string
    |> Parser.parse(mod)
    #|> Pathex.Combination.from_suggested_path()
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
        :get, arg ->
          with {:ok, res} <- unquote(a).(:get, arg) do
            unquote(b).(:get, {res})
          end

        :force_set, {struct, value} ->
          val =
            case unquote(a).(:get, {struct}) do
              :error       -> %{}
              {:ok, other} -> other
            end
          {:ok, val} = unquote(b).(:force_set, {val, value})
          unquote(a).(:force_set, {struct, val})

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

  # Helper for detecring mod
  defp detect_mod(mod) when mod in ~w(naive map json)a, do: mod
  defp detect_mod(str) when is_binary(str), do: detect_mod('#{str}')
  defp detect_mod('json'), do: :json
  defp detect_mod('map'), do: :map
  defp detect_mod(_), do: :naive

  defp build_only(path, opname, caller, mod \\ :naive) do
    %{^opname => builder} = Operations.from_mod(mod)
    path
    |> QuotedParser.parse(caller, mod)
    |> Builder.build_only(builder)
  end

end
