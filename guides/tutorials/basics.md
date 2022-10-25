# Basics

This guide will show the basics of `Pathex`. This is the best place to start learning `Pathex`.
It won't take more than 5 minutes.

As README says, Pathex is a library for working with collections and nested key-value structures.
Pathex uses a powerful functional abstraction called a lens (in Pathex we call it path or path-closure, you'll later see why).
Path is a basically a path to a value in a nested structure, almost like filesystem path.

## Create paths

First of all, we need to know how to create paths. A path can be created with the `Pathex.path/2` macro.

For example:

```elixir
p = path :x / :y
# Note the "/". That's why the library is called Pathex
```

This path specifies a way to get (or set, or delete or whatever) value `1` from `%{x: %{y: 1}}`

> Note:
> You **don't** have to pin variables used in paths
>
> ```elixir
> x = 1
> path :some_atom / x  # Right
> path :some_atom / ^x # Wrong
> ```

Each type of value used in a `path` corresponds to one or more types of Elixir collections

* Strings, tuples, maps, functions, lists are treated only as `Map` keys.
* Atoms are treated as `Map` or `Keyword` keys.
* Positive integers are treated as `Map` keys or `List` and `Tuple` indexes
* Negative integers are treated as `Map` keys or first element in `List`'s view or
  prepending element in `List`'s `update` or `force_set` operations
* Variables are treated the same way as the type they have in runtime. For example, variables containing negative
  integers are treated as negative integer values. Unfortunately, it is not possible to know variable type at compile-time,
  that's why `Pathex` generates code for all possible types. See [performance tips](basics.md#performance-tips) for more information.

## Use paths

Alright, we have a path. Now, we need to know how to use it

Let's take a value from nested structure

```elixir
iex> p = path :usernames / 0
iex> Pathex.view(%{usernames: ["SubZero", "Scorpion"]}, p)
{:ok, "SubZero"}
```

There are a lot of other ways to use paths. Every macro with human-readable name
(except `path`) is a macro for using path in some way, check `Pathex` documentation.
In all such macros, the first argument is an input structure and the second argument is a path-closure.

> Note:
> Path-closure which are created inside path-using macros are optimised to have
> only one operation generated (instead of default three).
> You can read more about path-closures and operations [here](path.md)

As usual

* Macros without `!` always return `{:ok, result}` or `:error`
* Macros with `!` return `result` or raise `Pathex.Error`

## Compose paths

Path-closures can be composed together to create new path-closure,
every path composition macro is a binary operator. Some compositions
are optimized to generate one closure even if multiple closures
are used.

You can concat paths with `Pathex.~>/2` composition macro

```elixir
iex> p1 = path :x
iex> p2 = path :y
iex> composed_path = p1 ~> p2
iex> 1 = Pathex.view(%{x: [y: 1]}, composed_path)
```

> Think about path composition just like path concatenation in shell  
> For example  
>
> ```elixir
> iex> first_user = path :users / 0          # users/0
> iex> name = path :name                     # name
> iex> first_user_name = first_user ~> name  # users/0/name
> ```

## Prebuilt paths

`Pathex` provides some prebuilt paths for non-standard data manipulation. You
can find them in `Pathex.Lenses` module. You can read more about them in
[lenses guide](lenses.md)

For example `Pathex.Lenses.star/0` lens works just like `*` in filesystem path.

## Performance tips

General rule: the more data you provide to `Pathex` at compile-time the better

For example:

```elixir
path(1 / :x / :y, :json)
# works faster than
path(1 / :x / :y)
```

Because `:json` mod optimizes the closure to one big case,
while the default `:naive` mod generates nested cases.

And, in this example:

```elixir
path(1 / :x / :y)
# works faster than
x = :x; path(1 / x / :y)
```

Because constants provide more information about available types.
This means that for `:x` Pathex knows that this can be a `Keyword` or `Map`,
while `x` means that this is a variable which could contain a `List`/`Tuple` index or a `Map`/`Keyword` value

And, in this example:

```elixir
path(1 / x / :y)
# works faster than
path(1) ~> path(x) ~> path(:y)
```

Because path concatenation actually creates a path that calls all operands internally
which increases the call stack and makes concatenated paths handle errors manually.
