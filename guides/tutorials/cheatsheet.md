# Cheatsheet

## Operations

For single-key operations `Pathex` is slightly slower than `Map` or `Keyword`

| Map             | Pathex                |
|:----------------|----------------------:|
| `Map.fetch/2`   | `Pathex.view/2`       |
| `Map.get/3`     | `Pathex.get/3`        |
| `Map.update!/3` | `Pathex.over/3`       |
| `Map.update/4`  | `Pathex.force_over/4` |
| `Map.put/3`     | `Pathex.force_set/3`  |
| `Map.replace/3` | `Pathex.set/3`        |
| `Map.delete/2`  | `Pathex.delete/2`     |

## Nested

`Pathex` is 2 to 4 times faster than `Access`

| Access                             | Pathex                                      |
|:-----------------------------------|--------------------------------------------:|
| `get_in(s, [:x, :y, :z])`          | `Pathex.get(s, path(:x / :y / :z))`         |
| `put_in(s, [:x, :y, :z], v)`       | `Pathex.set(s, path(:x / :y / :z), v)`      |

Note that `Pathex` works with structures (i.e. `%User{}`) like maps and doesn't need any special behaviour implemented in the module. Plus `Pathex` also works with tuples and lists

This means that this code
```
structure
|> get_in([:x, :y, :z])
|> Enum.at(10)
|> elem(1)
|> get_in([:z, :y, :x])
```

Can be rewritten to
```
Pathex.view(structure, path(:x / :y / :z / 10 / 1 / :z / :y / :x))
```

## Lenses

| Enum                | Pathex                 |
|:--------------------|-----------------------:|
| `Enum.find/2`       | `Pathex.Lenses.some/0` |
| `Enum.map/2`        | `Pathex.Lenses.all/0`  |
| `Enum.filter_map/3` | `Pathex.Lenses.star/0` |

[More examples in Lenses tutorial](lenses.md)

## Traverse leaves

This function traverses all leaves in the structure

```elixir
use Pathex; import Pathex.Combinator; import Pathex.Lenses

def leaves(iterlens \\ star()) do
  combine(fn recursive ->
    iterlens ~> (recursive ||| matching(_))
  end)
end

[2, 1, [:dot, 1234]] =
  %{
    x: 1,
    y: 2,
    meta: %{
      type: :dot,
      id: 1234
    }
  }
  |> Pathex.view!(leaves)
```

You can change the `star()` lens to whatever lens you prefer.
For example, for parsed HTML documents you can use `star() ~> path(2)` to
not traverse attributes. And if you want to find one leaf, you can use `some()`

## Walk structure

If you want to walk the whole structure, not only leaves, but the structure and it's substructures too, you can use this function

```elixir
use Pathex; import Pathex.Combinator; import Pathex.Lenses

# Like Macro.postwalk but for any tree-like structure
def postwalking(iterlens, predicate) do
  combine(fn recursive ->
    predicate
    ~> (
      alongside([
        iterlens ~> recursive,
        matching(_)
      ])
      ||| matching(_)
    )
    ||| (iterlens ~> recursive)
  end)
end

# Like Macro.prewalk but for any tree-like structure
def prewalking(iterlens, predicate) do
  combine(fn recursive ->
    predicate
    ~> (
      alongside([
        matching(_),
        iterlens ~> recursive
      ])
      ||| matching(_)
    )
    ||| (iterlens ~> recursive)
  end)
end

walking = postwalking(star(), matching(%{}))

# This code updates all maps and submaps in the structure
%{
  size: 3,
  x: 1,
  y: 2,
  meta: %{
    type: :dot,
    id: 1234,
    size: 3,
    empty_map_in_list: [[[%{size: 0}]]]
  }
} =
  %{
    x: 1,
    y: 2,
    meta: %{
      type: :dot,
      id: 1234,
      empty_map_in_list: [[[%{}]]]
    }
  }
  |> Pathex.over!(walking, & Map.put(&1, :size, map_size(&1)))
```
