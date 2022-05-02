defmodule Pathex do
  @moduledoc """
  This module contains functions and macros to be used with `Pathex` and i

  To use Pathex just insert to your context. You can import Pathex in module body or even in function body.
  ```elixir
  require Pathex
  import Pathex, only: [path: 1, path: 2, "~>": 2, ...]
  ```

  Or you can use `use`
  ```elixir
  defmodule MyModule do

    # `default_mod` option is optional
    # when no mod is specified, `:naive` is selected
    use Pathex, default_mod: :json

    ...
  end
  ```
  This will import all operatiors and `path` macro

  Any macro here belongs to one of three categories:
  1. Macro which creates path closure (only `path/2`)
  2. Macro which uses path closure as path (`over/3`, `set/3`, `view/2`, ...)
  3. Macro which creates path composition (`~>/2`, `|||/2`, ...)
  """

  alias Pathex.Builder
  alias Pathex.Combination
  alias Pathex.Common
  alias Pathex.Operations
  alias Pathex.QuotedParser

  @typedoc """
  Function which is passed to path-closure as second element in args tuple
  """
  @type inner_func :: (any() -> {:ok, any()} | :error)

  @type inspect_args :: any()
  @type update_args :: {pathex_compatible_structure(), inner_func()}
  @type force_update_args :: {pathex_compatible_structure(), inner_func(), any()}

  @typedoc "This depends on the modifier"
  @type pathex_compatible_structure :: map() | list() | Keyword.t() | tuple()

  @typedoc "Value returned by non-bang path call"
  @type result :: {:ok, any()} | :error

  @typedoc "Value returned by a valid path-closure call"
  @type internal_result :: {:ok, any()} | :error | :delete_me

  @typedoc "Also known as [path-closure](path.md)"
  @type t :: (op_name(), force_update_args() | update_args() | inspect_args() -> result())

  @typedoc "More about [modifiers](modifiers.md)"
  @type mod :: :map | :json | :naive

  @typep op_name :: Operations.name()

  @doc """
  Easy and convinient way to add pathex to your module.

  You can specify modifier
  ```elixir
  use Pathex, default_mod: :json
  ```

  Or just use it with default `:naive` modifier
  ```elixir
  use Pathex
  ```
  """
  defmacro __using__(opts) do
    case Keyword.get(opts, :default_mod, :naive) do
      :naive ->
        quote do
          require Pathex
          import Pathex, only: [path: 1, path: 2, ~>: 2, &&&: 2, |||: 2, alongside: 1]
        end

      mod when mod in ~w[json map]a ->
        quote do
          require Pathex
          import Pathex, only: [path: 1, path: 2, ~>: 2, &&&: 2, |||: 2, alongside: 1]


          @pathex_default_mod unquote(mod)
        end

      _wrong_mod ->
        raise ArgumentError, "Pathex only works with navie, json and map mods"
    end
  end

  @doc """
  Applies `func` to the item under the `path` in `struct`
  and returns modified structure. Works like `Map.update!/3` but doesn't raise.

  Example:
      iex> index = 1
      iex> inc = fn x -> x + 1 end
      iex> {:ok, [0, %{x: 9}]} = over [0, %{x: 8}], path(index / :x), inc
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [2, [2]]}} = over %{"hey" => [1, [2]]}, p, inc

  > Note:
  > Exceptions from passed function left unhandled
      iex> over(%{1 => "x"}, path(1), fn x -> x + 1 end)
      ** (ArithmeticError) bad argument in arithmetic expression
  """
  @doc export: true
  defmacro over(struct, path, func) do
    gen(path, :update, [struct, wrap_ok(func)], __CALLER__)
  end

  @doc """
  Applies the `func` to the item under `path` in `struct` and returns modified structure.
  Works like `Map.update!/3`.

  Example:
      iex> x = 1
      iex> inc = fn x -> x + 1 end
      iex> [0, %{x: 9}] = over! [0, %{x: 8}], path(x / :x), inc
      iex> p = path "hey" / 0
      iex> %{"hey" => [2, [2]]} = over! %{"hey" => [1, [2]]}, p, inc
  """
  @doc export: true
  defmacro over!(struct, path, func) do
    path
    |> gen(:update, [struct, wrap_ok(func)], __CALLER__)
    |> bang(struct, path)
  end

  @doc """
  Sets `value` under `path` in `structure`. Think of it like `Map.put/3`.

  Example:
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = set [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => [123, [2]]}} = set %{"hey" => [1, [2]]}, p, 123
  """
  @doc export: true
  defmacro set(struct, path, value) do
    gen(path, :update, [struct, quote(do: fn _ -> {:ok, unquote(value)} end)], __CALLER__)
  end

  @doc """
  Sets the `value` under `path` in `struct`. Think of it like `Map.put/3`.

  Example:
      iex> x = 1
      iex> [0, %{x: 123}] = set! [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> %{"hey" => [123, [2]]} = set! %{"hey" => [1, [2]]}, p, 123
  """
  @doc export: true
  defmacro set!(struct, path, value) do
    path
    |> gen(:update, [struct, quote(do: fn _ -> {:ok, unquote(value)} end)], __CALLER__)
    |> bang(struct, path)
  end

  @doc """
  Sets the `value` under `path` in `struct`.

  If the path does not exist it creates the path favouring maps
  when structure is unknown.

  Example:
      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = force_set [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_set %{}, p, 1

  If the item in path doesn't have the right type, it returns `:error`.

  Example:
      iex> p = path "hey" / "you"
      iex> :error = force_set %{"hey" => {1, 2}}, p, "value"
  """
  @doc export: true
  defmacro force_set(struct, path, value) do
    gen(
      path,
      :force_update,
      [struct, quote(do: fn _ -> {:ok, unquote(value)} end), value],
      __CALLER__
    )
  end

  @doc """
  Sets the `value` under `path` in `struct`.

  If the path does not exist it creates the path favouring maps
  when structure is unknown.

  Example:
      iex> x = 1
      iex> [0, %{x: 123}] = force_set! [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_set! %{}, p, 1

  If the item in path doesn't have the right type, it raises.

  Example:
      iex> p = path "hey" / "you"
      iex> force_set! %{"hey" => {1, 2}}, p, "value"
      ** (Pathex.Error) Type mismatch in structure
  """
  @doc export: true
  defmacro force_set!(struct, path, value) do
    path
    |> gen(
      :force_update,
      [struct, quote(do: fn _ -> {:ok, unquote(value)} end), value],
      __CALLER__
    )
    |> bang(struct, path, "Type mismatch in structure")
  end

  @doc """
  Applies `func` under `path` of `struct`.

  If the path does not exist it creates the path favouring maps
  when structure is unknown and inserts default value.

  Example:
      iex> x = 1
      iex> {:ok, [0, %{x: {:xxx, 8}}]} = force_over([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_over(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it returns `:error`.

  Example:
      iex> p = path "hey" / "you"
      iex> :error = force_over %{"hey" => {1, 2}}, p, fn x -> x end, "value"
  """
  @doc export: true
  defmacro force_over(struct, path, func, value \\ nil) do
    gen(path, :force_update, [struct, wrap_ok(func), value], __CALLER__)
  end

  @doc """
  Applies `func` under `path` of `struct`.

  If the path does not exist it creates the path favouring maps
  when structure is unknown and inserts default value.

  Example:
      iex> x = 1
      iex> [0, %{x: {:xxx, 8}}] = force_over!([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_over!(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it raises.

  Example:
      iex> p = path "hey" / "you"
      iex> force_over! %{"hey" => {1, 2}}, p, fn x -> x end, "value"
      ** (Pathex.Error) Type mismatch in structure
  """
  @doc export: true
  defmacro force_over!(struct, path, func, value \\ nil) do
    path
    |> gen(:force_update, [struct, wrap_ok(func), value], __CALLER__)
    |> bang(struct, path, "Type mismatch in structure")
  end

  @doc """
  Applies `func` under `path` in `struct` and returns result of this `func`.

  Example:
      iex> x = 1
      iex> {:ok, 9} = at [0, %{x: 8}], path(x / :x), fn x -> x + 1 end
      iex> p = path "hey" / 0
      iex> {:ok, {:here, 9}} = at(%{"hey" => {9, -9}}, p, & {:here, &1})
  """
  @doc export: true
  defmacro at(struct, path, func) do
    gen(path, :view, [struct, wrap_ok(func)], __CALLER__)
  end

  @doc """
  Applies `func` under `path` in `struct` and returns result of this `func`.
  Raises if path is not found.

  Example:
      iex> x = 1
      iex> 9 = at! [0, %{x: 8}], path(x / :x), fn x -> x + 1 end
      iex> p = path "hey" / 0
      iex> {:here, 9} = at!(%{"hey" => {9, -9}}, p, & {:here, &1})
  """
  @doc export: true
  defmacro at!(struct, path, func) do
    path
    |> gen(:view, [struct, wrap_ok(func)], __CALLER__)
    |> bang(struct, path)
  end

  @doc """
  Gets the value under `path` in `struct`.

  Example:
      iex> x = 1
      iex> {:ok, 8} = view [0, %{x: 8}], path(x / :x)
      iex> p = path "hey" / 0
      iex> {:ok, 9} = view %{"hey" => {9, -9}}, p
  """
  @doc export: true
  defmacro view(struct, path) do
    gen(path, :view, [struct, quote(do: fn x -> {:ok, x} end)], __CALLER__)
  end

  @doc """
  Gets the value under `path` in `struct`. Raises if `path` not found.

  Example:
      iex> x = 1
      iex> 8 = view! [0, %{x: 8}], path(x / :x)
      iex> p = path "hey" / 0
      iex> 9 = view! %{"hey" => {9, -9}}, p
  """
  @doc export: true
  defmacro view!(struct, path) do
    path
    |> gen(:view, [struct, quote(do: fn x -> {:ok, x} end)], __CALLER__)
    |> bang(struct, path)
  end

  @doc """
  Gets the value under `path` in `struct` or returns `default` when `path` is not present.

  Example:
      iex> x = 1
      iex> 8 = get([0, %{x: 8}], path(x / :x))
      iex> p = path "hey" / "you"
      iex> nil = get(%{"hey" => [x: 1]}, p)
      iex> :default = get(%{"hey" => [x: 1]}, p, :default)
  """
  @doc export: true
  defmacro get(struct, path, default \\ nil) do
    res = gen(path, :view, [struct, quote(do: fn x -> {:ok, x} end)], __CALLER__)

    quote do
      case unquote(res) do
        {:ok, value} -> value
        :error -> unquote(default)
      end
    end
    |> Common.set_generated()
  end

  @doc """
  Gets the value under `path` in `struct` or returns default value if not found.

  Example:
      iex> x = 1
      iex> true = exists?([0, %{x: 8}], path(x / :x))
      iex> p = path "hey" / "you"
      iex> false = exists?(%{"hey" => [x: 1]}, p)
  """
  @doc export: true
  defmacro exists?(struct, path) do
    res = gen(path, :view, [struct, quote(do: fn _ -> true end)], __CALLER__)

    quote do
      with :error <- unquote(res) do
        false
      end
    end
    |> Common.set_generated()
  end

  @doc """
  Deletes value under `path` in `struct`.

  Example:
      iex> x = 1
      iex> {:ok, [0, %{}]} = delete([0, %{x: 8}], path(x / :x))
      iex> :error = delete([0, %{x: 8}], path(1 / :y))
  """
  @doc export: true
  defmacro delete(struct, path) do
    path
    |> gen(:delete, [struct, quote(do: fn _ -> :delete_me end)], __CALLER__)
    |> wrap_delete_me()
  end

  @doc """
  Deletes value under `path` in `struct` or raises if value is not found.

  Example:
      iex> x = 1
      iex> [0, %{}] = delete!([0, %{x: 8}], path(x / :x))
  """
  @doc export: true
  defmacro delete!(struct, path) do
    path
    |> gen(:delete, [struct, quote(do: fn _ -> :delete_me end)], __CALLER__)
    |> wrap_delete_me()
    |> bang(struct, path)
  end

  defp wrap_delete_me(call) do
    quote do
      with :delete_me <- unquote(call) do
        :error
      end
    end
  end

  @doc """
  Macro which gets value in the structure and deletes it

  Example:
      iex> {:ok, {1, [2, 3]}} = pop([1, 2, 3], path(0))
  """
  @doc export: true
  defmacro pop(struct, path) do
    view = gen(path, :view, [struct, quote(do: fn x -> {:ok, x} end)], __CALLER__)
    delete = gen(path, :delete, [struct, quote(do: fn _ -> :delete_me end)], __CALLER__)

    quote do
      with(
        {:ok, value} <- unquote(view),
        {:ok, structure} <- unquote(delete)
      ) do
        {:ok, {value, structure}}
      end
    end
  end

  @doc """
  Gets value under `path` in `struct` and then deletes it.

  Example:
      iex> {1, [2, 3]} = pop!([1, 2, 3], path(0))
  """
  @doc export: true
  defmacro pop!(struct, path) do
    view =
      path
      |> gen(:view, [struct, quote(do: fn x -> {:ok, x} end)], __CALLER__)
      |> bang(struct, path)

    delete =
      path
      |> gen(:delete, [struct, quote(do: fn _ -> :delete_me end)], __CALLER__)
      |> wrap_delete_me()
      |> bang(struct, path)

    quote do
      value = unquote(view)
      structure = unquote(delete)
      {value, structure}
    end
  end

  @doc """
  Creates path from `quoted` ast. Paths look like unix fs path and consist of
  elements separated from each other with `/`. See 

  For example:
      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
      iex> structure = [0, [atom: %{"string" => %{{"tuple?"} => %{1 => 2}}}]]
      iex> {:ok, 2} = view structure, mypath

  Default [modifier](modifiers.md) of this `path/2` is `:naive` which means that
  * Every variable is treated as index or key to tuple, list, map and keyword
  * Every atom is treated as key to map or keyword
  * Every integer is treated as index to tuple, list or key to map
  * Every other data type is treated as key to map

  > Note:  
  > `-1` allows data to be prepended to the list
      iex> x = -1
      iex> p1 = path(-1)
      iex> p2 = path(x)
      iex> {:ok, [1, 2]} = force_set([2], p1, 1)
      iex> {:ok, [1, 2]} = force_set([2], p2, 1)
  """
  @doc export: true
  defmacro path(quoted, mod \\ nil) do
    mod = get_mod(mod, __CALLER__)

    combination =
      quoted
      |> QuotedParser.parse(__CALLER__, mod)
      |> assert_combination_length(__CALLER__)

    combination
    |> Builder.build(Operations.builders_for_combination(combination))
    |> Common.set_generated()
  end

  @doc """
  Creates composition of two paths similar to concating them together.  
  This means that `a ~> b` path-closure applies `a` and only if it returns `{:ok, something}`
  it applies `b` to `something`

  Example:
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> composed_path = p1 ~> p2
      iex> {:ok, 1} = view %{x: [y: [a: [a: 0, b: 1]]]}, composed_path
  """
  @doc export: true
  defmacro a ~> b, do: do_concat(a, b, __CALLER__)

  @doc """
  The same as `Pathex.~>/2` for those who do not like operators

  Example:
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> composed_path = concat(p1, p2)
      iex> {:ok, 1} = view %{x: [y: [a: [a: 0, b: 1]]]}, composed_path
  """
  @doc export: true
  defmacro concat(a, b), do: do_concat(a, b, __CALLER__)

  defp do_concat(a, b, caller) do
    {:~>, [], [a, b]}
    |> QuotedParser.parse_composition(:~>)
    |> Builder.build_composition(:~>, caller)
    |> Common.set_generated()
  end

  @doc """
  Creates composition of two paths which has some inspiration from logical `and`.  
  This means that `a &&& b` path-closure tries to apply `a` and only if it returns `{:ok, something}`, tries
  apply `b` and if `b` returns **exactly the same** as `a` does, the `a &&& b` returns `{:ok, something}`

  Example:
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> ap = p1 &&& p2
      iex> {:ok, 1} = view %{x: %{y: 1}, a: [b: 1]}, ap
      iex> :error = view %{x: %{y: 1}, a: [b: 2]}, ap
      iex> {:ok, %{x: %{y: 2}, a: [b: 2]}} = set %{x: %{y: 1}, a: [b: 1]}, ap, 2
      iex> {:ok, %{x: %{y: 2}, a: %{b: 2}}} = force_set %{}, ap, 2
  """
  @doc export: true
  defmacro a &&& b do
    {:&&&, [], [a, b]}
    |> QuotedParser.parse_composition(:&&&)
    |> Builder.build_composition(:&&&, __CALLER__)
    |> Common.set_generated()
  end

  @doc """
  Creates composition of two paths which has some inspiration from logical `or`.  
  This means that `a ||| b` path-closure tries to apply `a` and only if it returns `:error`, tries
  apply `b`

  Example:
      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> op = p1 ||| p2
      iex> {:ok, 1} = view %{x: %{y: 1}, a: [b: 2]}, op
      iex> {:ok, 2} = view %{x: 1, a: [b: 2]}, op
      iex> {:ok, %{x: %{y: 2}, a: [b: 1]}} = set %{x: %{y: 1}, a: [b: 1]}, op, 2
      iex> {:ok, %{x: %{y: 2}}} = force_set %{}, op, 2
      iex> {:ok, %{x: %{}, a: [b: 1]}} = force_set %{x: %{y: 1}, a: [b: 1]}, op, 2
  """
  @doc export: true
  defmacro a ||| b do
    {:|||, [], [a, b]}
    |> QuotedParser.parse_composition(:|||)
    |> Builder.build_composition(:|||, __CALLER__)
    |> Common.set_generated()
  end

  @doc """
  This macro creates compositions of paths which work along with each other

  Think of `alongside([path1, path2, path3])` as `path1 &&& path2 &&& path3`
  The only difference is that for viewing alongside returns list of variables

  Example:
      iex> pa = alongside [path(:x), path(:y)]
      iex> {:ok, [1, 2]} = view(%{x: 1, y: 2}, pa)
      iex> {:ok, %{x: 3, y: 3}} = set(%{x: 1, y: 2}, pa, 3)
      iex> :error = set(%{x: 1}, pa, 3)
      iex> {:ok, %{x: 1, y: 1}} = force_set(%{}, pa, 1)
  """
  @doc export: true
  defmacro alongside(list) do
    list
    |> Builder.build_composition(:alongside, __CALLER__)
    |> Common.set_generated()
  end

  @doc """
  Inspect the given path-closure and returns string which corresponds to given path-closure

  Example:
      iex> index = 1
      iex> p = path(:x) ~> path(:y / index) &&& path(-1)
      iex> Pathex.inspect(p)
      "path(:x) ~> path(:y / 1) &&& path(-1)"
  """
  @spec inspect(Pathex.t()) :: iodata()
  def inspect(path_closure) when is_function(path_closure, 2) do
    path_closure.(:inspect, [])
    |> Macro.to_string()
  end

  # Helpers

  # Helper for generating code for path operation
  # Special case for inline paths
  defp gen({:path, _, [path | tail]}, op, args, caller) do
    mod =
      tail
      |> List.first()
      |> get_mod(caller)

    path_func = build_only(path, op, caller, mod)

    quote generated: true do
      unquote(path_func).(unquote_splicing(args))
    end
    |> Common.set_generated()
  end

  # Case for not inlined paths
  defp gen(path, op, args, _caller) do
    quote generated: true do
      unquote(path).(unquote(op), {unquote_splicing(args)})
    end
    |> Common.set_generated()
  end

  defp wrap_ok(func) do
    quote do
      fn x -> {:ok, unquote(func).(x)} end
    end
  end

  # Helper for generating raising functions
  @spec bang(Macro.t(), Operations.t(), Macro.t(), binary()) :: Macro.t()
  defp bang(quoted, structure, path, err_str \\ "Couldn't find element") do
    quote generated: true do
      case unquote(quoted) do
        {:ok, value} ->
          value

        :error ->
          raise Pathex.Error,
            message: unquote(err_str),
            path: unquote(path),
            structure: unquote(structure)
      end
    end
  end

  defp get_mod(nil, %Macro.Env{module: nil}), do: :naive

  defp get_mod(nil, %Macro.Env{module: module}) do
    Module.get_attribute(module, :pathex_default_mod) || :naive
  end

  defp get_mod(mod, _), do: detect_mod(mod)

  # Helper for detecting mod
  @spec detect_mod(mod() | charlist()) :: mod() | no_return()
  defp detect_mod(mod) when mod in ~w[naive map json]a, do: mod
  defp detect_mod(str) when is_binary(str), do: detect_mod('#{str}')
  defp detect_mod('json'), do: :json
  defp detect_mod('map'), do: :map
  defp detect_mod('naive'), do: :naive
  defp detect_mod(_), do: raise("Can't have this modifier set")

  # Builds only one clause of a path
  defp build_only(path, opname, caller, mod) do
    combination =
      path
      |> fetch_args(caller)
      |> QuotedParser.parse(caller, mod)

    %{^opname => builder} = Operations.builders_for_combination(combination)
    Builder.build_only(combination, builder)
  end

  defp fetch_args(path, caller) do
    case Macro.prewalk(path, &Macro.expand(&1, caller)) do
      {{:., _, [__MODULE__, :path]}, _, args} ->
        args

      {:path, meta, args} = full ->
        case Keyword.fetch(meta, :import) do
          {:ok, __MODULE__} ->
            args

          _ ->
            full
        end

      args ->
        args
    end
  end

  # This function raises warning if combination will lead to very big closure
  @maximum_combination_size 256
  defp assert_combination_length(combination, env) do
    size = Combination.size(combination)

    if size > @maximum_combination_size do
      {func, arity} = env.function || {:nofunc, 0}
      stacktrace = [{env.module, func, arity, [file: '#{env.file}', line: env.line]}]

      """
      This path will generate too many clauses, and therefore will slow down
      the compilation and increase amount of generated code. Current
      combination has #{size} clauses while suggested amount is #{@maximum_combination_size}

      It would be better to split this closure in different paths with `Pathex.~>/2`
      Or change the modifier to one which generates less code: `:map` or `:json`
      """
      |> IO.warn(stacktrace)
    end

    combination
  end
end
