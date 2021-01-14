# Pathex

Fast. Really fast.

## What is Pathex?

Pathex is a library for performing fast actions with nested data structures in Elixir.
With pathex you can trivially set, get and update values in structures.
It provides all necessary logic to manipulate data structures in different ways

## Why another library?

Existing methods of accesssing data in nested structures are either slow (`Focus` for example)
or do not provide much functionality (`put_in` or `get_in` for example).
For example setting the value in structure with Pathex is `70-160x` faster than `Focus` or `2x` faster than `put_in` and `get_in`

> You can checkout benchmarks at https://github.com/hissssst/pathex_bench

## Check out Pathex documentation!

You can find complete documentation with examples, howto's, guides at https://hexdocs.pm/pathex

## Installation

```elixir
def deps do
  [
    {:pathex, "~> 1.0.0"}
  ]
end
```

## Usage

1. You need to import and require Pathex since it mainly operates macros
   ```elixir
   require Pathex
   import Pathex, only: [path: 1, path: 2, "~>": 2]
   ```
   Or you can just `use` Pathex!
   ```elixir
   # This will require Pathex and import all operators and path/2 macro
   use Pathex
   ```

2. You need to create the path which defines the path to the item in elixir structure you want to get:
   ```elixir
   path_to_strees = path :user / :private / :addresses / 0 / :street
   path_in_json = ~P"users/1/street"json
   ```
   This creates closure with `fn` which can get, set and update values in this path

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

1. Paths are really a set of pattern-matching cases. This is done to extract maximum efficency from BEAM's pattern-matching compiler
   ```elixir
   # code for viewing variables for path
   iex> path 1 / "y"
   # almost equals to
   case do
     %{1 => x} ->
       case x do
         %{"y" => res} -> {:ok, res}
         _ -> :error
       end
     [_, x | _] ->
       case x do
         %{"y" => res} -> {:ok, res}
         _ -> :error
       end
     t when is_tuple(t) and tuple_size(t) > 1 ->
       case x do
         %{"y" => res} -> {:ok, res}
         _ -> :error
       end
   end
   ```
2. Paths for special specifications can be created with sigils
   ```elixir
   iex> mypath = ~P[user/name/firstname]json
   iex> Pathex.over(%{"user" => %{"name" => %{"firstname" => "hissssst"}}}, mypath, &String.capitalize/1)
   {:ok, %{"user" => %{"name" => %{"firstname" => "Hissssst"}}}}
   ```
   ```elixir
   iex> mypath = ~P[:hey/"hey"]naive
   iex> Pathex.set([hey: %{"hey" => 1}], mypath, 2)
   {:ok, [hey: %{"hey" => 2}]}
   ```
3. You can use variables inside paths
   ```elixir
   iex> index = 1
   iex> mypath = path :name / index
   iex> Pathex.view %{name: {"Linus", "Torvalds"}}, mypath
   {:ok, "Torvalds"}
   iex> index = 0 # Note that captured variables can not be overriden
   iex> Pathex.view %{name: {"Linus", "Torvalds"}}, mypath
   {:ok, "Torvalds"}
   ```
4. You can create composition of lenses
   ```elixir
   iex> path1 = path :user
   iex> path2 = path :phones / 1
   iex> composed_path = path1 ~> path2
   iex> Pathex.view %{user: %{phones: ["123-456-789", "987-654-321", "000-111-222"]}}, composed_path
   {:ok, "987-654-321"}
   ```
5. Paths can be applied to different types of structures
   ```elixir
   iex> user_path = path :user
   iex> Pathex.view %{user: "hissssst"}, user_path
   {:ok, "hissssst"}
   iex> Pathex.view [user: "hissssst"], user_path
   {:ok, "hissssst"}
   ```


## No Magic

Pathex paths are just closures created with `fn`.
Any `path` or `~P` is a macro for creating a closure.
`Pathex.view/2`, `Pathex.set/3`, `Pathex.over/3` and etc are just macros for calling these closures.
`Pathex.~>/2` is a simple macro which creates composition of two closures

## Contributions

Welcome! You can check existing `TODO`'s

---

* If you have any suggestions or wan't to change something in this library don't hesitate to open an issue
* If you have any whitepapers about functional lenses, you can add them in a PR to the bottom of this readme
