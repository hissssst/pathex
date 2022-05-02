# Lenses tutorial

This guide will show you how to create powerful lenses using `Pathex.Lenses` module. Here we will take a look at common tasks in nested data structure manipulation which can be solved using `Pathex.Lenses`.

## For all values in collection

What if we need to update all values in the collection matching specific pattern?

This simple task can be solved using Elixir's `Enum` module but is kind of tought
to be polymorphic and reusable for different patterns or types of collections

Let's say we have a list of users with roles and we want to add access to admin
page for all admins:

```elixir
# The list looks like this
users = [
  %{fname: "John", sname: "Doe", role: "CEO",   access: ["admin_page", "users_page"]},
  %{fname: "Mike", sname: "Lee", role: "admin", access: ["users_page"]},
  %{fname: "Fred", sname: "Can", role: "admin", access: ["users_page"]},
  %{fname: "Dave", sname: "Lee", role: "user",  access: []}
]
```

With `Enum` this would look like

```elixir
new_users =
  Enum.map(users, fn
    %{role: "admin", access: access} = user ->
      %{user | access: Enum.uniq(["admin_page" | access])}

    other ->
      other
  end)
```

But using `Pathex.Lenses.star/0` and `Pathex.Lenses.matching/1` this would look like

```elixir
import Pathex
import Pathex.Lenses

# `l` in the end stands for `lens`
adminl = matching(%{role: "admin"})
accessl = path(:access)

# `star()` works like `*` in shell.
# so `star() ~> path(:file)` works almost like `*/file`

# Here `star() ~> adminl` translates to `select * where role == "admin"`
# and `star() ~> adminl ~> accessl` translates to `select access where role == "admin"`
new_users = Pathex.over!(users, star() ~> adminl ~> accessl, & Enum.uniq(["admin_page" | &1]))
```

## For any value in collection

What if we need to update first value matching specific pattern
(in our example it will be `{:option, _}`) and we need to
return `{:ok, updated_collection}` if the
first value was updated and `:error` if not

This task can be also done using `Enum`, but what if we can write the solution  
which would be as simple as saying `Update first value in collection, which matches the pattern`?

With `Enum` this would look really terrible.
I couldn't come up with polymorphic solution which would fit less than 20 lines of code

But with `Pathex.Lenses.some/0` and `Pathex.Lenses.matching/1` this would be as simple as

```elixir
use Pathex; import Pathex.Lenses
def update_first_option(collection, update_func) do
  Pathex.over(collection, some() ~> matching({:option, _}), update_func)
end
```

## For any value in nested structure

Alright, we have a nested structure with various types inside and we need to find any value in any map
for which the special condition occurs and change it

Think of an HTML-like structure without attributes like
```elixir
{"html", [
  {"head", [...]},
  {"body", [...]}
  ]}
```

And we need to update __just one__ `label` with string which ends with `"Please click subscribe button"`

In Elixir we'd need to write a recursive function, which would untrivially update tuples and lists

Using `Pathex.Combinator.combine/1`, `Pathex.Lenses.some/0` and `Pathex.Lenses.filtering/1` it's very simple

```elixir
use Pathex; import Pathex.Lenses; import Pathex.Lenses.Recur

path_to_subscribe =
  combine(fn recursive -> some() ~> (recursive() ||| matching()) end)
  ~> matching({"label", _}) # To find a label
  ~> path(1)               # To get to value of a label
  ~> filtering(& String.ends_with?(&1, "Please click subscribe button")

Pathex.set(document, path_to_subscribe, "Do not subscribe, hehe")
```

## Recurring

Sometimes you may want to create a recurring lens. We have a `Pathex.Combinator.combine/1` which can help you. It is a fixed point combinator for paths, what may sound too smart, but this is a function which makes your lens be able to compose with itself.

Consider this representation of an HTML
```
{"html", [], [
  {"body", [], ...}
  {"html", [], ...}]}
```

And we want to update a node which has `id=big-image`. It would be nice to have a lens which would do something like
```elixir
path(2) ~> some()
  ~> path(2) ~> some()
    ~> path(2) ~> some()`
```
Until it finds the tag we're looking for.

Meet the `Pathex.Combinator.combine/1`. Using this higher order function we can represent lens combining with itself.
The lens above can be specified with this code.
```elixir
combine(fn recursive ->
  path(2) ~> some() ~> recursive
end)
```

And we also need to find a specific id, so let's combine this lens with `matching(_)`
```elixir
path_to_id =
  combine(fn recursive ->
    path(2) ~> some ~> recursive
  end)
  ~> matching({_, [{"id", "big-image"}], _})
```

However, it has a drawback -- this recursive lens will never succeed, because we didn't specify the exit. Let's fix it
```elixir
path_to_big_image =
  combine(fn recursive ->
    path(2) ~> some ~> (recursive ||| matching(_))
  end)
  ~> matching({_, [{"id", "big-image"}], _})

{"div", [{"id", "big-image"}], [
  {"img", [{"src", "/image.png"}], ""}]} = Pathex.view!(html, path_to_big_image)
```
