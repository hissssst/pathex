# Pathex

Fast. Really fast.

## What is Pathex?

Pathex is a library for performing fast actions with nested data structures in Elixir.
With pathex you can trivially set, get and update values in structures.
It provides all necessary logic to manipulate data structures in different ways

## Why another library?

Existing methods of accesssing data in nested structures are either slow (like `Focus`)
or do not provide much functionality (like `put_in` or `get_in`).
For example setting the value in structure with Pathex is `70-160x` faster than `Focus` or `2-3x` faster than `put_in` and `get_in`

> You can checkout benchmarks at https://github.com/hissssst/pathex_bench

## Check out Pathex documentation!

You can find complete documentation with examples, howto's, guides at https://hexdocs.pm/pathex

## Installation

```elixir
def deps do
  [
    {:pathex, "~> 1.0"}
  ]
end
```

## Usage

1. Import it

   ```elixir
   require Pathex
   import Pathex, only: [path: 1, path: 2, "~>": 2]
   ```

   > Or you can just `use` Pathex!
   >
   > ```elixir
   > # This will require Pathex and import all operators and path/2 macro
   > use Pathex
   > ```

2. Create path

   ```elixir
   path_to_strees = path :user / :private / :addresses / 0 / :street
   path_in_json = ~P"users/1/street"json
   ```

   This creates closure which can get, set and update values in this path

3. Use the path!

   ```elixir
   {:ok, "6th avenue" = street} =
       %{
         user: %{
           id: 1,
           name: "hissssst",
           private: %{
             phone: "123-456-789",
             addresses: [
                [city: "City", street: "6th avenue", mail_index: 123456]
             ]
           }
         }
       }
       |> Pathex.view(path_to_streets)
   %{
     "users" => %{
       "1" => %{"street" => "6th avenue"}
     }
   } = Pathex.force_set!(%{}, path_in_json, street)
   ```

## Features

### Speed

Paths are really a set of pattern-matching cases.
This is done to extract maximum efficency from BEAM's pattern-matching compiler

```elixir
# Code for viewing variables for path
path(1 / "y", :map)

# Almost equals to
case do
  %{1 => %{"y" => res}} -> {:ok, res}
  _                     -> :error
end
   ```

### Reusability

Paths can be created and used or composed later with rich set of composition functions

```elixir
# Takes username from user structure
username = path(:personal / :fname)

{:ok, "Kabs"} =
  %{
    personal: %{fname: "Kabs", sname: "Rocks"},
    phone: "123-456-789"
  }

# Takes all usernames!
all = Pathex.Lenses.all()

{:ok, ["Kabs", "Blabs"]} =
  [
    %{
      personal: %{fname: "Kabs", sname: "Rocks"},
      phone: "123-456-789"
    },
    %{
      personal: %{fname: "Blabs"},
      phone: "123-456-790"
    }
  ]
  |> Pathex.view(all ~> username)
```

### Rich toolkit

Perform create, update, select operation with different behaviours using `Pathex.Lenses` module
High level operations like filtering and updating nested values have never been this easy

```elixir
import Pathex; import Pathex.Lenses

# Change first username in a list
[
  %{personal: %{fname: "Alabs", sname: "Rocks"}},
  %{personal: %{fname: "Blabs"}}
] =
  [
    %{personal: %{fname: "Kabs", sname: "Rocks"}},
    %{personal: %{fname: "Blabs"}}
  ]
  |> Pathex.set!(some() ~> path(:personal / :fname), "Alabs")
```

### Powerfull abstraction

Pathex is built around simple primitive called `path`, therefore can be simply extended.  
`path` or `path-closure` is just a closure with special primitives. Anything complying with `Pathex.t()` spec can
be used within `Pathex`

### Safe and simple

All path-closures are pure and macro are hygienic. There is no magic

## Contributions

Welcome! You can check existing `TODO`'s

---

By the way

* If you have any suggestions or want to change something in this library don't
hesitate to open an issue
* If you have any whitepapers about functional lenses, you can add them in a PR
to the bottom of this readme
