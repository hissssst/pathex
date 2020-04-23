# Pathex

Brings power of filesystem paths to elixir!

## Installation

```elixir
def deps do
  [
    {:pathex, github: "hissssst/pathex"}
  ]
end
```

## Usage

1. You need to import and require Pathex since it's manly operates macros
```
require Pathex
import Pathex, only: [path: 1, "~>": 2]
```

2. You need to create the path which defines the path to the item in elixir structure you want to get:
```elixir
path_to_strees = path :user / :private / :addresses / 0 / :street
```
This creates closure with `fn` which can get, set and update values in this path

3. Use the path!
```elixir
{:ok, "6th avenue"} = Pathex.get(path_to_streets, %{
  user: %{
    id: 1,
    name: "hissssst",
    private: %{
      phone: "123-456-789",
      adressess: [
         [city: "City", street: "6th avenue", mail_index: 123456]
      ]
    }
  }
})
```

## Features

1. Paths are really a set of pattern-matching cases. This is done to extract maximum efficency from BEAM
```elixir
# getter for
path 1 / "y"
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
iex> Pathex.update(mypath, %{"user" => %{"name" => %{"firstname" => "hissssst"}}}, &String.capitalize/1)
{:ok, %{"user" => %{"name" => %{"firstname" => "Hissssst"}}}}
```
```elixir
iex> mypath = ~P[:hey/"hey"]naive
iex> Pathex.set(mypath, [hey: %{"hey" => 1}], 2)
{:ok, [hey: %{"hey" => 2}]}
```
