# Lenses tutorial

This guide will show you how to create powerful lenses using `Pathex.Lenses` module

## Why

`Pathex.Lenses` module provides functions and macro for creating lenses which can
work with collections, do pattern-matching and solve common problems in an elegant
and reusable way

## Common tasks

Here we will take a look at common tasks in nested data structure manipulation

### Star lens

What if we need to update all values matching matching specific pattern

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

But using `Pathex.Lenses` this would look like

```elixir
use Pathex
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

### Some lens

What if we need to update first value matching specific pattern
(in our example it will be `{:hello, _}`) and we need to
return `{:ok, updated_collection}` if the
first value was updated and `:error` if not

This task can be also done using `Enum`, but what if we can write the solution  
which would be as simple as saying `Update first value in collection, which matches the pattern`?

With `Enum` this would look really terrible.
I couldn't come up with polymorphic solution which would fit less than 20 lines of code

But with `Pathex.Lenses` this would be as simple as

```elixir
use Pathex; import Pathex.Lenses
def update_first_hello(collection, update_func) do
  hellol = matching({:hello, _})
  Pathex.over(collection, some() ~> hellol, update_func)
end
```

### Matching lens

Conditional lens, which returns the value if the value itself matches the given pattern

```elixir
use Pathex
import Pathex.Lenses

adminl = matching(%{role: :admin})

user1 = %User{role: :user, name: "Mr Dog"}
:error = Pathex.view(user1, adminl)

user2 = %User{role: :admin, name: "Mr Dog"}
{:ok, ^user2} = Pathex.view(user2, adminl)
```

Most useful lens in combination with `start` and `some`

```elixir
use Pathex
import Pathex.Lenses

@spec change_roles([User.t()]) :: :ok
def change_roles(users) do
  adminsl = star() ~> matching(%{role: :admin})
  Pathex.at(users, adminsl, &send_email/1)

  :ok
end
```
