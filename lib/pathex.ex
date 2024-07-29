defmodule Pathex do
  @moduledoc """
  This module contains main functions and macros used to create, use and manipulate paths.

  ### Usage

  To use Pathex just insert to your context. You can import Pathex in module body or even in function body.
  ```elixir
  require Pathex
  import Pathex, only: [path: 1, path: 2, "~>": 2, ...]
  ```

  Or you can just `use Pathex`.
  ```elixir
  defmodule MyModule do

    # `default_mod` option is optional
    # when no mod is specified, `:naive` is selected
    use Pathex, default_mod: :json

    ...
  end
  ```
  This will import all operatiors and `path` macro

  ### Available macros

  Any macro here belongs to one of three categories:
  1. Macro which creates path closure (only `path/2`)
  2. Macro which uses path closure to manipulate the value (like `over/3`, `set/3`, `view/2`, ...)
  3. Macro which creates some path composition (like `alongside/1`, `~>/2`, `|||/2`, ...)
  """

  alias Pathex.Builder
  alias Pathex.Builder.Viewer
  alias Pathex.Combination
  alias Pathex.Common
  alias Pathex.Operations
  alias Pathex.QuotedParser

  import Kernel, except: [inspect: 2]

  defmacrop raise_incorrect_modifier(mod) do
    quote do
      mod = unquote(mod)

      formatted =
        try do
          mod
          |> Macro.to_string()
          |> Code.format_string!()
        rescue
          _ -> Kernel.inspect(mod)
        end

      raise CompileError,
        description: "Incorrect modifier. Expected :naive, :json or :map. Got #{formatted}"
    end
  end

  defguardp is_mod(m) when m in ~w[naive map json]a

  @typedoc """
  Function which is passed to path-closure as second element in args tuple
  """
  @type inner_func(output) :: (any() -> result(output))

  @type inspect_args :: any()
  @type update_args(input, output) :: {input, inner_func(output)}
  @type force_update_args(input, output) :: {input, inner_func(output), any()}

  @typedoc "This depends on the modifier"
  @type pathex_compatible_structure :: map() | list() | Keyword.t() | tuple()

  @typedoc "Value returned by non-bang path call"
  @type result(inner) :: {:ok, inner} | :error | :delete_me

  @typedoc "Also known as [path-closure](path.md)"
  @type t :: t(pathex_compatible_structure(), any())

  @typedoc "Also known as [path-closure](path.md)"
  @type t(input, output) ::
          (op_name(),
           force_update_args(input, output)
           | update_args(input, output)
           | inspect_args() ->
             result(output | input) | Macro.t())

  @typedoc "More about [modifiers](modifiers.md)"
  @type mod :: :map | :json | :naive

  @typep op_name :: Operations.name()

  @doc """
  Easy and convenient way to add pathex to your module.

  You can specify modifier
  ```elixir
  use Pathex, default_mod: :json
  ```

  Or just use it with default `:naive` modifier
  ```elixir
  use Pathex
  ```

  > #### `use Pathex` {: .info}
  >
  > When you `use Pathex`, the Pathex module will
  > require `Pathex` and import `Pathex`'s operators, `path/2` and `alongside/1` macros.
  > Plus it will set special module attribute with `default_mod` value in it.
  """
  @doc export: true
  defmacro __using__(opts) do
    case Keyword.get(opts, :default_mod, :naive) do
      mod when is_mod(mod) ->
        if module = __CALLER__.module do
          Module.put_attribute(module, :pathex_default_mod, mod)
        end

        quote do
          require Pathex
          require Pathex.Lenses
          import Pathex, only: [path: 1, path: 2, ~>: 2, &&&: 2, |||: 2, alongside: 1]
        end

      wrong_mod ->
        raise_incorrect_modifier(wrong_mod)
    end
  end

  @doc """
  Applies `func` to the item under the `path` in `struct`
  and returns modified structure. Works like `Map.update!/3` but doesn't raise.

  ## Example

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

  ## Example

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

  ## Example

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

  ## Example

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

  ### Creates path if it is not present

  If the path does not exist it creates the path favouring maps
  when structure is unknown.

      iex> x = 1
      iex> {:ok, [0, %{x: 123}]} = force_set [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_set %{}, p, 1

  ### Incorrect types may be detected during call

  If the item in path doesn't have the right type, it returns `:error`.

      iex> p = path "hey" / "you"
      iex> :error = force_set %{"hey" => {1, 2}}, p, "value"

  ### Empty space is filled with nil

  Note that for paths created with `Pathex.path/2` list and tuple indexes
  which are out of bounds fill the empty space with `nil`.

      iex> p = path 4
      iex> {:ok, [1, 2, 3, nil, 5]} = force_set [1, 2, 3], p, 5
      iex> {:ok, {1, 2, 3, nil, 5}} = force_set {1, 2, 3}, p, 5

  ### Negative indexes

  This is also true for negative indexes (except -1 for lists which always prepends)

      iex> p = path -5
      iex> {:ok, [0, nil, 1, 2, 3]} = force_set [1, 2, 3], p, 0
      iex> {:ok, {0, nil, 1, 2, 3}} = force_set {1, 2, 3}, p, 0
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

  ### Creates path if it is not present

  If the path does not exist it creates the path favouring maps
  when structure is unknown.

      iex> x = 1
      iex> [0, %{x: 123}] = force_set! [0, %{x: 8}], path(x / :x), 123
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_set! %{}, p, 1

  ### Incorrect types may be detected during call

  If the item in path doesn't have the right type, it raises.

      iex> p = path "hey" / "you"
      iex> force_set! %{"hey" => {1, 2}}, p, "value"
      ** (Pathex.Error) Type mismatch in structure

  ### Empty space is filled with nil

  Note that for paths created with `Pathex.path/2` list and tuple indexes
  which are out of bounds fill the empty space with `nil`.

      iex> p = path 4
      iex> [1, 2, 3, nil, 5] = force_set! [1, 2, 3], p, 5
      iex> {1, 2, 3, nil, 5} = force_set! {1, 2, 3}, p, 5

  ### Negative indexes

  This is also true for negative indexes (except `-1` for lists which always prepends)

      iex> p = path -5
      iex> [0, nil, 1, 2, 3] = force_set! [1, 2, 3], p, 0
      iex> {0, nil, 1, 2, 3} = force_set! {1, 2, 3}, p, 0
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

  ## Example

      iex> x = 1
      iex> {:ok, [0, %{x: {:xxx, 8}}]} = force_over([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> {:ok, %{"hey" => %{0 => 1}}} = force_over(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it returns `:error`.

  ## Example

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

  ## Example

      iex> x = 1
      iex> [0, %{x: {:xxx, 8}}] = force_over!([0, %{x: 8}], path(x / :x), & {:xxx, &1}, 123)
      iex> p = path "hey" / 0
      iex> %{"hey" => %{0 => 1}} = force_over!(%{}, p, fn x -> x + 1 end, 1)

  If the item in path doesn't have the right type, it raises.

  ## Example

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

  ## Example

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

  ## Example

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

  ## Example

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

  ## Example

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
  Note that the default value is always lazily evaluted.

  ## Example

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

  ## Example

      iex> x = 1
      iex> true = exists?([0, %{x: 8}], path(x / :x))
      iex> p = path "hey" / "you"
      iex> false = exists?(%{"hey" => [x: 1]}, p)
  """
  @doc export: true
  defmacro exists?(struct, path) do
    res = gen(path, :view, [struct, quote(do: fn _ -> {:ok, []} end)], __CALLER__)

    quote do
      case unquote(res) do
        {:ok, _} -> true
        :error -> false
      end
    end
    |> Common.set_generated()
  end

  @doc """
  Deletes value under `path` in `struct`.

  ## Example

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

  ## Example

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
  Macro which gets value in the structure and deletes it.
  > Note:
  >
  > Current implementation of this function performs double lookup.
  > Which is still more efficient than `pop_in`

  ## Example

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
  > Note:
  >
  > Current implementation of this function performs double lookup.
  > Which is still more efficient than `pop_in`

  ## Example

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
  Creates path from `quoted` ast. Paths look like unix filesystems paths and consist of
  elements separated from each other with `/`. Each element defines the key or index
  in the collection.

  ## Example

      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
      iex> structure = [0, [atom: %{"string" => %{{"tuple?"} => %{1 => 2}}}]]
      iex> {:ok, 2} = view structure, mypath

  Paths can be used with one of the verbs in `Pathex` module (for example, `Pathex.view/2`).
  Paths can be customized with [modifiers](modifiers.md), composed using one of
  composition operators (`Pathex.concat/2`, `Pathex.~>/2`, `Pathex.|||/2`, `Pathex.&&&/2` or
  `Pathex.alongside/1`).

  > Note:
  > Each element in path can have collection type annotated using `::` operator. Available collection
  > types are `:list`, `:keyword`, `:tuple` and `:map`. Multiple collections can be annotated using list
  > It must comply with the limits set with [modifier](modifiers.md).

  ## Example

      iex> p = path( (0 :: [:list, :map]) / (:x :: :keyword) )
      iex> {:ok, :hit} = view %{0 => [x: :hit]}, p
      iex> {:ok, :hit} = view [[x: :hit]], p
      iex> :error = view [%{x: :hit}], p
  """
  @doc export: true
  defmacro path(quoted, mod \\ nil) do
    mod = get_mod(mod, __CALLER__)
    {binds, combination} = QuotedParser.parse(quoted, __CALLER__, mod)

    combination
    |> assert_combination_length(__CALLER__)
    |> Builder.build(Operations.builders_for_combination(combination))
    |> Common.set_generated()
    |> prepend_binds(binds)
  end

  @doc """
  Creates composition of two paths similar to concatenating them together.
  This means that `a ~> b` path-closure applies `a` and only if it returns `{:ok, something}`
  it applies `b` to `something`

  ## Example

      iex> p1 = path :x / :y
      iex> p2 = path :a / :b
      iex> composed_path = p1 ~> p2
      iex> {:ok, 1} = view %{x: [y: [a: [a: 0, b: 1]]]}, composed_path
  """
  @doc export: true
  defmacro a ~> b, do: do_concat(a, b, __CALLER__)

  @doc """
  The same as `Pathex.~>/2` for those who do not like operators

  ## Example

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

  ## Example

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

  ## Example

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

  ## Example

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

  ## Example

      iex> index = 1
      iex> p = path(:x) ~> path(:y / index) &&& path(-1)
      iex> Pathex.inspect(p)
      "path(:x) ~> path(:y / 1) &&& path(-1)"
  """
  @spec inspect(Pathex.t()) :: iodata()
  @doc export: true
  def inspect(path_closure) when is_function(path_closure, 2) do
    Macro.to_string(path_closure.(:inspect, []))
  end

  @doc """
  This macro converts path (which can be matched upon) into pattern.

  These requirements must be satisfied in order for this macro to work correctly:
  1. Path must be inlined into this macro. This means that path must be defined
  in a argument of this macro
  2. Defined paths must contain constants only
  3. Path must result only in case with one clause

  ## Example

      iex> import Pathex
      iex> structure = %{users: %{1 => %{fname: "Jose", lname: "Valim"}}}
      iex> case structure do
      ...>   pattern(fname, path(:users / 1 / :fname, :map)) ->
      ...>     {:ok, fname}
      ...>
      ...>   _ ->
      ...>     :error
      ...> end
      {:ok, "Jose"}
  """
  @doc export: true
  defmacro pattern(variable \\ {:_, [], Elixir}, path) do
    {:ok, path, mod} =
      with :error <- destruct_inlined(path, __CALLER__) do
        raise CompileError, description: "You can't have uninlined paths in pattern"
      end

    mod = get_mod(mod, __CALLER__)

    if not Macro.Env.in_match?(__CALLER__) do
      raise CompileError, description: "You can't use this macro outside of pattern"
    end

    with(
      {[], combination} <- QuotedParser.parse(path, __CALLER__, mod),
      [path] <- Pathex.Combination.to_paths(combination),
      {:ok, match} <- Viewer.match_from_path(path, variable)
    ) do
      match
    else
      paths when is_list(paths) ->
        raise CompileError, description: "Unfortunately, this path defines more than one pattern"

      {:error, _} ->
        raise CompileError, description: "Can't generate matching from this combination"

      {_binds, _combination} ->
        raise CompileError,
          description: "You can only use variables and constants in pattern matching"

      _other ->
        raise CompileError, description: "Unknown error"
    end
  end

  # Helpers

  # Helper for generating code for path operation
  defp gen(code, op, args, caller) do
    case destruct_inlined(code, caller) do
      # Special case for inline paths
      {:ok, path, mod} ->
        path_func = build_only(path, op, caller, get_mod(mod, caller))

        quote generated: true do
          unquote(path_func).(unquote_splicing(args))
        end
        |> Common.set_generated()

      # Case for not inlined paths
      :error ->
        quote generated: true do
          unquote(code).(unquote(op), {unquote_splicing(args)})
        end
        |> Common.set_generated()
    end
    # |> tap(fn x -> IO.puts Macro.to_string x end)
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
  rescue
    error in ArgumentError ->
      IO.warn("""
      You've attemted to compile the path within the enviroment which
      is different from the original env. Therefore, Pathex was unable
      to get the default modifier (which is bound to the env), so
      `:naive` will be used

      Original error: #{Exception.message(error)}
      """)

      :naive
  end

  defp get_mod(mod, _) when is_mod(mod), do: mod

  defp get_mod(mod, _) do
    raise_incorrect_modifier(mod)
  end

  # Builds only one clause of a path
  defp build_only(path, opname, caller, mod) do
    {binds, combination} =
      path
      |> fetch_args(caller)
      |> QuotedParser.parse(caller, mod)

    %{^opname => builder} = Operations.builders_for_combination(combination)

    combination
    |> Builder.build_only(builder)
    |> prepend_binds(binds)
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
  defp assert_combination_length(none, env) when none in [[], [[]]] do
    stacktrace = extract_stacktrace(env)

    """
    This path will never match. If this is intended behaviour, just
    ignore this message or use something like `Pathex.Lenses.filtering(fn _ -> false end)`.
    If this behaviour is unintended, please refer to documentation of mods you're using.
    """
    |> IO.warn(stacktrace)

    []
  end

  defp assert_combination_length(combination, env) do
    size = Combination.size(combination)

    if size > @maximum_combination_size do
      stacktrace = extract_stacktrace(env)

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

  defp extract_stacktrace(%Macro.Env{function: function, module: module, line: line, file: file}) do
    {func, arity} = function || {:nofunc, 0}
    [{module, func, arity, [file: ~c"#{file}", line: line]}]
  end

  defp prepend_binds(combination, binds) do
    quote do
      unquote_splicing(binds)
      unquote(combination)
    end
  end

  defp destruct_inlined({:path, meta, [path | mod]}, env) do
    case Keyword.fetch(meta, :import) do
      {:ok, Pathex} ->
        {:ok, path, maybemod(mod)}

      :error ->
        case Macro.Env.lookup_import(env, {:path, 2}) do
          [{:macro, Pathex} | _] ->
            {:ok, path, maybemod(mod)}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp destruct_inlined({{:., _, [m, :path]}, _, [path | mod]}, env) do
    case Macro.expand(m, env) do
      Pathex ->
        {:ok, path, maybemod(mod)}

      _ ->
        :error
    end
  end

  defp destruct_inlined(_, _), do: :error

  defp maybemod([]), do: nil
  defp maybemod([mod]) when is_mod(mod), do: mod

  defp maybemod(mod) do
    raise_incorrect_modifier(mod)
  end
end
