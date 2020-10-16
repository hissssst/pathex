defmodule Pathex do

  @moduledoc """
  Main module. Use it inside your project to call Pathex macroses

  To use it just insert
  ```elixir
  defmodule MyModule do

    require Pathex
    import Pathex, only: [path: 1, path: 2, "~>": 2, ...]

    ...
  end
  ```

  > Note:
  > There is no `__using__/2` macro avaliable here
  > because it would be better to explicitly define that the
  > `Pathex` is used and what macroses are exported

  Any macro here belongs to one of two categories:
  1. Macro which creates path closure (`sigil_P/2`, `path/2`, `~>/2`)
  2. Macro which uses path closure as path (`over/3`, `set/3`, `view/2`, etc.)
  """

  alias Pathex.Builder
  alias Pathex.Operations
  alias Pathex.Parser
  alias Pathex.QuotedParser

  @typep update_args :: {pathex_compatible_structure(), (any() -> any())}
  @typep force_update_args :: {pathex_compatible_structure(), (any() -> any()), any()}

  @typedoc "This depends on the modifier"
  @type pathex_compatible_structure :: map() | list() | Keyword.t() | tuple()

  @typedoc "Value returned by non-bang path call"
  @type result :: {:ok, any()} | :error

  @typedoc "Also known as [path-closure](path.md)"
  @type t :: (Operations.name(), force_update_args() | update_args() -> result())

  @typedoc "More about [modifiers](modifiers.md)"
  @type mod :: :map | :json | :naive

  @doc """
  Macro of three arguments which applies given function
  for item in the given path of given structure
  and returns modified structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> inc = fn x -> x + 1 end
      iex> {:ok, [0, %{x: 9}]} = over [0, %{x: 8}], path(x / :x), inc
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [2, [2]]}} = over %{"hey" => [1, [2]]}, p, inc

  > Note:
  > Exceptions from passed function left unhandled
      iex> require Pathex; import Pathex
      iex> over(%{1 => "x"}, path(1), fn x -> x + 1 end)
      ** (ArithmeticError) bad argument in arithmetic expression
  """
  defmacro over(struct, path, func) do
    gen(path, :update, [struct, func], __CALLER__)
  end

  @doc """
  Macro of three arguments which applies given function
  for item in the given path of given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> inc = fn x -> x + 1 end
      iex> [0, %{x: 9}] = over! [0, %{x: 8}], path(x / :x), inc
      iex> p = path "hey" / 0
      iex> %{"hey" => [2, [2]]} = over! %{"hey" => [1, [2]]}, p, inc
  """
  defmacro over!(struct, path, func) do
    path
    |> gen(:update, [struct, func], __CALLER__)
    |> bang()
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = set [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [123, [2]]}} = set %{"hey" => [1, [2]]}, p, 123
  """
  defmacro set(struct, path, value) do
    gen(path, :update, [struct, quote(do: fn _ -> unquote(value) end)], __CALLER__)
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> [0, %{x: 123}] = set! [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> %{"hey" => [123, [2]]} = set! %{"hey" => [1, [2]]}, p, 123
  """
  defmacro set!(struct, path, value) do
    path
    |> gen(:update, [struct, quote(do: fn _ -> unquote(value) end)], __CALLER__)
    |> bang()
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = force_set [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_set %{}, p, 1

  If the item in path doesn't have the right type, it returns `:error`
  Example:
      iex> require Pathex; import Pathex
      iex> p = path "hey" / "you"
      iex> :error = force_set %{"hey" => {1, 2}}, p, "value"
  """
  defmacro force_set(struct, path, value) do
    gen(path, :force_update, [struct, quote(do: fn _ -> unquote(value) end), value], __CALLER__)
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> [0, %{x: 123}] = force_set! [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_set! %{}, p, 1

  If the item in path doesn't have the right type, it raises
  Example:
      iex> require Pathex; import Pathex
      iex> p = path "hey" / "you"
      iex> force_set! %{"hey" => {1, 2}}, p, "value"
      ** (Pathex.Error) Type mismatch in structure
  """
  defmacro force_set!(struct, path, value) do
    path
    |> gen(:force_update, [struct, quote(do: fn _ -> unquote(value) end), value], __CALLER__)
    |> bang("Type mismatch in structure")
  end

  @doc """
  Macro of four arguments which applies given function
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown and inserts default value

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, [0, %{x: {:xxx, 8}}]} = force_over([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_over(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it returns `:error`
  Example:
      iex> require Pathex; import Pathex
      iex> p = path "hey" / "you"
      iex> :error = force_over %{"hey" => {1, 2}}, p, fn x -> x end, "value"

  > Note:
  > Default "default" value is nil
  """
  defmacro force_over(struct, path, func, value \\ nil) do
    gen(path, :force_update, [struct, func, value], __CALLER__)
  end

  @doc """
  Macro of four arguments which applies given function
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown and inserts default value

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> [0, %{x: {:xxx, 8}}] = force_over!([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_over!(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it raises
  Example:
      iex> require Pathex; import Pathex
      iex> p = path "hey" / "you"
      iex> force_over! %{"hey" => {1, 2}}, p, fn x -> x end, "value"
      ** (Pathex.Error) Type mismatch in structure

  > Note:
  > Default `default` value is `nil`
  """
  defmacro force_over!(struct, path, func, value \\ nil) do
    path
    |> gen(:force_update, [struct, func, value], __CALLER__)
    |> bang("Type mismatch in structure")
  end

  @doc """
  Macro returns function applyed to the value in the path
  or error

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, 9} = at [0, %{x: 8}], path(x / :x), fn x -> x + 1 end
      iex> p = path "hey" / 0
      iex> {:ok, {:here, 9}} = at(%{"hey" => {9, -9}}, p, & {:here, &1})
  """
  defmacro at(struct, path, func) do
    gen(path, :view, [struct, func], __CALLER__)
  end

  @doc """
  Macro returns function applyed to the value in the path
  or error

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> 9 = at! [0, %{x: 8}], path(x / :x), fn x -> x + 1 end
      iex> p = path "hey" / 0
      iex> {:here, 9} = at!(%{"hey" => {9, -9}}, p, & {:here, &1})
  """
  defmacro at!(struct, path, func) do
    path
    |> gen(:view, [struct, func], __CALLER__)
    |> bang()
  end

  @doc """
  Macro gets the value in the given path of the given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> {:ok, 8} = view [0, %{x: 8}], path(x / :x)
      iex> p = path "hey" / 0
      iex> {:ok, 9} = view %{"hey" => {9, -9}}, p
  """
  defmacro view(struct, path) do
    gen(path, :view, [struct, quote(do: fn x -> x end)], __CALLER__)
  end

  @doc """
  Macro gets the value in the given path of the given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> 8 = view! [0, %{x: 8}], path(x / :x)
      iex> p = path "hey" / 0
      iex> 9 = view! %{"hey" => {9, -9}}, p
  """
  defmacro view!(struct, path) do
    path
    |> gen(:view, [struct, quote(do: fn x -> x end)], __CALLER__)
    |> bang()
  end

  @doc """
  Macro gets the value in the given path of the given structure
  or returns default value if not found

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> 8 = get [0, %{x: 8}], path(x / :x)
      iex> p = path "hey" / "you"
      iex> :default = get %{"hey" => [x: 1]}, p, :default
  """
  defmacro get(struct, path, default \\ nil) do
    res = gen(path, :view, [struct, quote(do: fn x -> x end)], __CALLER__)
    quote do
      case unquote(res) do
        {:ok, value} -> value
        :error -> unquote(default)
      end
    end
    |> set_generated()
  end

  @doc """
  Sigil for paths. Three [modifiers](modifiers.md) are avaliable:
  * `naive` (default) paths should look like `~P["string"/:atom/1]`
  * `json` paths should look like `~P[string/this_one_is_too/1/0]json`
  * `map` paths should look like `~P[:x/1]map`

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
      iex> structure = [0, [atom: %{"string" => %{{"tuple?"} => %{1 => 2}}}]]
      iex> {:ok, 2} = view structure, mypath
  """
  defmacro sigil_P({_, _, [string]}, mod) do
    mod = detect_mod(mod)
    string
    |> Parser.parse(mod)
    |> assert_combination_length(__CALLER__)
    |> Builder.build(Operations.from_mod(mod))
    |> set_generated()
  end

  @doc """
  Creates path for given structure

  Example:
      iex> require Pathex; import Pathex
      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
      iex> structure = [0, [atom: %{"string" => %{{"tuple?"} => %{1 => 2}}}]]
      iex> {:ok, 2} = view structure, mypath

  Default [modifier](modifiers.md) of this `path/2` is `:naive` which means that
  * every variable is treated as index / key to any of tuple, list, map, keyword
  * every atom is treated as key to map or keyword
  * every integer is treated as index to tuple, list or key to map
  * every other data is treated as key to map

  > Note:
  > `-1` allows data to be prepended to the list
      iex> require Pathex; import Pathex
      iex> x = -1
      iex> p1 = path(-1)
      iex> p2 = path(x)
      iex> {:ok, [1, 2]} = force_set([2], p1, 1)
      iex> {:ok, [1, 2]} = force_set([2], p2, 1)
  """
  defmacro path(quoted, mod \\ 'naive') do
    mod = detect_mod(mod)
    quoted
    |> QuotedParser.parse(__CALLER__, mod)
    |> assert_combination_length(__CALLER__)
    |> Builder.build(Operations.from_mod(mod))
    |> set_generated()
  end

  @doc """
  Creates composition of two paths similar to concating them together

  Example:
      iex> require Pathex; import Pathex
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> composed_path = p1 ~> p2
      iex> {:ok, 1} = view %{x: [y: [a: [a: 0, b: 1]]]}, composed_path
  """
  defmacro a ~> b do
    quote generated: true, bind_quoted: [a: a, b: b] do
      fn
        :view, {input_struct, func} ->
          with {:ok, res} <- a.(:view, {input_struct, func}) do
            b.(:view, {res, func})
          end

        :force_update, {input_struct, function, value} ->
          with {:ok, other} <- b.(:force_update, {%{}, function, value}) do
            a.(:force_update, {input_struct, fn v ->
              b.(:force_update, {v, function, value})
              |> case do
                {:ok, v} -> v
                :error   -> throw :path_not_found
              end
            end, other})
          end

        :update, {input_struct, func} ->
          a.(:update, {input_struct, fn inner ->
            b.(:update, {inner, func})
            |> case do
              {:ok, v} -> v
              :error   -> throw :path_not_found
            end
          end})
      end
    end
    |> set_generated()
  end

  @doc """
  This macro creates compositions of paths which work along with each other

  Example:
      iex> require Pathex; import Pathex
      iex> p1 = path :x
      iex> p2 = path :y
      iex> pa = alongside [p1, p2]
      iex> {:ok, [1, 2]} = view(%{x: 1, y: 2}, pa)
      iex> {:ok, %{x: 3, y: 3}} = set(%{x: 1, y: 2}, pa, 3)
      iex> {:ok, %{x: 1, y: 1}} = force_set(%{}, pa, 1)
  """
  defmacro alongside(list) do
    quote generated: true, bind_quoted: [list: list] do
      fn
        :view, {input_struct, func} ->
          list
          |> Enum.reverse()
          |> Enum.reduce_while({:ok, []}, fn path, {:ok, res} ->
            case path.(:view, {input_struct, func}) do
              {:ok, v} -> {:cont, {:ok, [v | res]}}
              :error   -> {:halt, :error}
            end
          end)

        :update, {input_struct, func} ->
          Enum.reduce_while(list, {:ok, input_struct}, fn path, {:ok, res} ->
            case path.(:update, {res, func}) do
              {:ok, res} -> {:cont, {:ok, res}}
              :error     -> {:halt, :error}
            end
          end)

        :force_update, {input_struct, func, default} ->
          Enum.reduce_while(list, {:ok, input_struct}, fn path, {:ok, res} ->
            case path.(:force_update, {res, func, default}) do
              {:ok, res} -> {:cont, {:ok, res}}
              :error     -> {:halt, :error}
            end
          end)
      end
    end
    |> set_generated()
  end

  @doc """
  Creates composition of two paths which has some inspiration from logical `and`

  Example:
      iex> require Pathex; import Pathex
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> ap = p1 &&& p2
      iex> {:ok, 1} = view %{x: %{y: 1}, a: [b: 1]}, ap
      iex> :error = view %{x: %{y: 1}, a: [b: 2]}, ap
      iex> {:ok, %{x: %{y: 2}, a: [b: 2]}} = set %{x: %{y: 1}, a: [b: 1]}, ap, 2
      iex> {:ok, %{x: %{y: 2}, a: %{b: 2}}} = force_set %{}, ap, 2
  """
  # This code is generated with experimental composition generator
  defmacro a &&& b do
    code =
      {:"&&&", [], [a, b]}
      |> QuotedParser.parse_composition(:"&&&")
      |> Builder.build_composition(:"&&&")
      |> set_generated()

    # code
    # |> Macro.to_string()
    # |> IO.puts

    code
  end

  @doc """
  Creates composition of two paths which has some inspiration from logical `or`

  Example:
      iex> require Pathex; import Pathex
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> ap = p1 ||| p2
      iex> {:ok, 1} = view %{x: %{y: 1}, a: [b: 2]}, ap
      iex> {:ok, 2} = view %{x: 1, a: [b: 2]}, ap
      iex> {:ok, %{x: %{y: 2}, a: [b: 1]}} = set %{x: %{y: 1}, a: [b: 1]}, ap, 2
      iex> {:ok, %{x: %{y: 2}}} = force_set %{}, ap, 2
  """
  defmacro a ||| b do
    quote generated: true, bind_quoted: [a: a, b: b] do
      fn
        :view, {input_struct, func} ->
          with :error <- a.(:view, {input_struct, func}) do
            b.(:view, {input_struct, func})
          end

        :update, {input_struct, func} ->
          with :error <- a.(:update, {input_struct, func}) do
            b.(:update, {input_struct, func})
          end

        :force_update, {input_struct, func, default} ->
          with :error <- a.(:force_update, {input_struct, func, default}) do
            b.(:force_update, {input_struct, func, default})
          end
      end
    end
    |> set_generated()
  end

  # Helper for generating code for path operation
  # Special case for inline paths
  defp gen({:path, _, [path]}, op, args, caller) do
    path_func = build_only(path, op, caller)
    quote generated: true do
      unquote(path_func).(unquote_splicing(args))
    end
    |> set_generated()
  end
  # Case for not inlined paths
  defp gen(path, op, args, _caller) do
    quote generated: true do
      unquote(path).(unquote(op), {unquote_splicing(args)})
    end
    |> set_generated()
  end

  # Helper for generating raising functions
  defp bang(quoted, err_str \\ "Coundn't find element in given path") do
    quote do
      case unquote(quoted) do
        {:ok, value} -> value
        :error -> raise Pathex.Error, unquote(err_str)
      end
    end
    |> set_generated()
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

  # This functions puts `generated: true` flag in meta for every node in AST
  # to avoid raising errors for dead code and stuff
  defp set_generated(ast) do
    Macro.prewalk(ast, fn item ->
      Macro.update_meta(item, & Keyword.put(&1, :generated, true))
    end)
  end

  # This function raises warning if combination will lead to very big closure
  @maximum_combination_size 128
  defp assert_combination_length(combination, env) do
    size = Enum.reduce(combination, 1, & length(&1) * &2)
    if size > @maximum_combination_size do
      {func, arity} = env.function || {:nofunc, 0}
      stacktrace = [{env.module, func, arity, [file: '#{env.file}', line: env.line]}]
      """
      This path will generate too many clauses, and therefore will slow down the compilation
      and increase amount of generated code. Size of current combination is #{size} while suggested
      size is #{@maximum_combination_size}

      We would suggest you to split this closure in different paths with with `Pathex.~>/2`
      Or change the modifier to one which generates less code: `:map` or `:json`
      """
      |> IO.warn(stacktrace)
    end
    combination
  end

  defmodule Error do
    @moduledoc """
    Simple exception for bang! functions errors.
    Some new field may be added in the future
    """
    defexception [:message]
  end

end
