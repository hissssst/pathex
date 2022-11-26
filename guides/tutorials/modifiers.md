# Modifiers tutorial

Every pathex `path` created with `Pathex.path/2` can have modifier specified as a second argument.
Modifier defines behaviour of the path in a way of structures it can match inside.
For example, path created with `:map` modifier can only match maps inside them.
Modifiers can be specified only in form of an atom, variables are not accepted.

## When? How? & Why?

You should use modifiers when you need to specify type of inner structures to match
or reduce amount of generated code by `Pathex` or improve performance of the path

## Usage

Currently only three modifiers are available:

* `:json` which matches lists and maps
* `:naive` which matches lists, tuples, keywords and maps
* `:map` which matches only maps

> Default modifier for every path is `:naive`

Modifiers are specified as second argument in `path/2` like

```elixir
path :x / :y, :naive
path 0 / :x, :json
```

## Naive modifier

This modifier matches lists, tuples, keyword and maps
It generates matches for every structure like

### For example:

`path(:x, :naive)` generates something like

```elixir
case input do
  %{x: value} ->
     ...
  [{a, _} | _] = k when is_atom(a) ->
     case Keyword.fetch(k, :x) do
       ...
     end
end
```

## Json modifier

This modifier specifies paths which macth lists (for integer keys only) and maps

> Note:
> This modifier treats variables as map keys, this means that
>
> ```elixir
> iex> x = 1
> iex> p = path x, :json
> iex> :error = Pathex.view([1, 2, 3], p)
> iex> {:ok, :x} = Pathex.view(%{1 => :x}, p)
> ```

But passed integers are exanded into list matching
this makes it very efficient to view data from the structure

### For example:

`path 1 / :x, :json` generates closure with

```elixir
case input do
  [_, %{x: value} | _] ->
    {:ok, value}

  %{1 => %{x: value}} ->
    {:ok, value}

  _ ->
    :error
end
```

Which extracts maximum efficiency from BEAM's pattern-matching

## Map modifier

This modifier matches only maps and therefore is the fastest modifier available

### For example:

`path 1 / :x / "y", :map` will generate closure with

```elixir
case input do
  %{1 => %{x: %{"y" => value}}} ->
    {:ok, value}

  _ ->
    :error
end
```

## Annotations

Usually a key passed to `path` can match to one or more types. For example, key `:x` can be a key in `Map` like `%{x: 1}` and a key in `Keyword` like `[x: 1]`. To make key match only certain type it can be annotated to the exact type using this syntax `path(:x :: :map)`. Available annotations are `:map`, `:keyword`, `:list` and `:tuple`.

### For example:

```elixir
first_in_tuple = path(1 :: :tuple)
:error   = Pathex.view([0, 1, 2, 3], first_in_tuple)
{:ok, 0} = Pathex.view({0, 1, 2, 3}, first_in_tuple)
```
