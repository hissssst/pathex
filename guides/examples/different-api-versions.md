# Different API Versions

## About

This tutorial shows the example of how `Pathex` solves some common data manipulation problems
while it creates one more layer of abstraction. If you will have some problems with examples you can
refer to `test/guides/different_api_verstions_test.exs` to have some more information about usage

## The Problem

Imagine a situation when you need to support different version of API.

For example you webapplication path `/api/v1/users` should respond:

```json
[
  {
    "id": 1,
    "name": "Username1",
    "personal_data": {
      "phone": "123",
      "address": {
        "street": "6th ave",
        "house":  "7/a"
      }
    }
  },
  {
    "id": 2,
    "name": "Username2",
    "personal_data": {
      "phone": "456",
      "address": {
        "street": "1st ave",
        "house":  "8/b"
      }
    }
  }
]
```

And `/api/v2/users` should respond:

```json
{
  1: {
    "id":     1,
    "name":   "Username1",
    "phone":  "123",
    "street": "6th ave",
    "house":  "7/a"
  },
  2: {
    "id":     2,
    "name":   "Username2",
    "phone":  "456",
    "street": "1st ave",
    "house":  "8/b"
  }
}
```

But your `%User{}` representation looks like this:

```elixir
%User{
  id: 1,
  name: "Username1",
  phone: "123",
  address: %Address{
    id: 2,
    street: "1st ave",
    house: "8/b"
  }
}
```

## Part 1. Straightforward approach

You would have probably written different Views for different versions.
But this is not the best solution because

* You have to change every View for every change in the inner replresentation user-structure
* You have to write completely new module for every new api version
* You have to write document2structures decoder for every api version
* You can't operate with parsed json while staying independent from api version

## Part 2. Using closures with Pathex

To be inner-user-structure independent we should create lenses for User

```elixir
defmodule User do

  use Pathex, default_mod: :map

  ...

  @doc "This function returns lens for passed user attribute"
  @spec attrlens(atom()) :: Pathex.t()
  def attrlens(attr) when attr in ~w[street house]a do
    path :address / attr
  end
  def attrlens(attr) do
    path attr
  end

end
```

And define single view which builds data using paths

```elixir
defmodule ApiView do

  use Pathex, default_mod: :map

  @attrs ~w[id name phone street house]a

  @doc "Creates structure from users list"
  def users_to_model(users, version) do
    Enum.reduce(users, [], & add_user(&1, &2, version))
  end

  @doc "Adds user to model"
  def add_user(%User{} = user, model, ver) do
    Enum.reduce(@attrs, model, fn attr, model ->
      with(
        {:ok, value} <- Pathex.view(user, User.attrlens(attr)),
        {:ok, model} <- Pathex.force_set(model, userlens(ver, user, model) ~> attrlens(ver, attr), value)
      ) do
        model
      else
        _ -> model
      end
    end)
  end

  defp empty_model(:v1), do: []
  defp empty_model(:v2), do: %{}

  # This functions defines where to put user
  defp userlens(:v1, %User{id: id}, model) do
    idx = Enum.find_index(model, & match?(%{id: ^id}, &1)) || -1
    path idx, :naive
  end
  defp userlens(:v2, %User{id: id}, _) do
    path id
  end

  # This function defines where to put attribute in user
  defp attrlens(:v1, attr) when attr in ~w[id name]a do
    path attr
  end
  defp attrlens(:v1, attr) when attr in ~w[street house]a do
    path :personal_data / :address / attr
  end
  defp attrlens(:v1, attr) do
    path :personal_data / attr
  end
  # For version 2
  defp attrlens(:v2, attr) do
    path attr
  end

end
```

## Part 3. Functional flavour

Not much changed, it seems. But what if we make it more abstract and define another module for
converting list of structures to aggregatable view back and forth

```elixir
defmodule StructuresToAggregatableView do

  use Pathex

  @doc "Converts list of users into model"
  def to_model(users, ver, %{
    attrs:         attrs,
    userattrl:     userattrl,
    userl:         userl,
    modelattrl:    modelattrl,
    initial_model: model
  }) do
    for user <- users, attr <- attrs, reduce: model.(ver) do
      model ->
        modell = userl.(ver, user.id, model) ~> modelattrl.(ver, attr)
        with(
          {:ok, value} <- Pathex.view(user, userattrl.(attr)),
          {:ok, model} <- Pathex.force_set(model, modell, value)
        ) do
          model
        else
          _ -> model
        end
    end
  end

  @doc "Converts model into list of users"
  def to_users(model, ver, %{
    attrs:      attrs,
    userattrl:  userattrl,
    modelattrl: modelattrl,
    modeliteml: modeliteml
  }) do
    for item <- model, into: [] do
      for attr <- attrs, reduce: %{} do
        user ->
          with(
            {:ok, value} <- Pathex.view(item, modeliteml.(ver) ~> modelattrl.(ver, attr)),
            {:ok, user}  <- Pathex.force_set(user, userattrl.(attr), value)
          ) do
            user
          else
            _ ->
              user
          end
      end
    end
  end
end
```

In this module we can use same configuration for every function. Looks nice but both functions
seem to look the same way...

## Part 4. Completely functional

```elixir
defmodule AggrToAggr do

  require Pathex

  @doc "Function which converts one aggregatable data structure to another back and forth"
  def convert(from, %{
    froml:   froml,   # Closure which returns path to attribute in input structure's item
    tol:     tol,     # Closure which returns path to attribute in output structure's item
    initial: initial, # Initial output structure which will be used to insert items into
    inner:   inner,   # Initial output structure's item which will be filled with values of attributes
    keys:    keys     # List of attributes to be called
  }) do
    Enum.into(from, initial, fn item ->
      Enum.reduce(keys, inner, fn key, acc ->
        with(
          {:ok, value} <- Pathex.view(item, froml.(key)),
          {:ok, acc}   <- Pathex.force_set(acc, tol.(key), value)
        ) do
          acc
        else
          _ -> acc
        end
      end)
    end)
  end

end
```

This module uses `Enum.into/3` to create aggregatable structure from other
aggregatable structure with two lenses, inner value and initial output
structure. The downside of this decidion is that we can't pass version
number straight into the closure, but we can creates partially filled closure
with `& userl.(ver, &1)`

### Did we solve the problems?

> 1. You have to change every View for every change in the inner replresentation user-structure

We need to change only one functon, the one which returns path to attribute in `User`

> 2. You have to write completely new module for every new api version

You just need to specify one function, the one which returns path to attribute in model

> 3. You have to write document2structures decoder for every api version

With pathex encoding-decoding process works back and forth

> 4. You can't operate with parsed json while staying independent from api version

You can take value from the model with function (which returns path) you've created for this version of model
