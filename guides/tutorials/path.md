# Path

> Note:  
> This is a documentation about internal Pathex API and it is subject to change  
> You do not need to read this unless you are interested in `Pathex` internals, want to hack `Pathex` or want to create your own `Pathex` compatible lens

This page describes what a `Pathex.t()` is and how to create and use one.
Most of the time you might want to use `Pathex.path/2` and `Pathex.Lenses` to create paths.
If you find their functionality limited and unapplicable for your use case, you can create you own Pathex-compatible closure. This doc describes how to do this.

## Path-closure

Path-closure is specified in `Pathex.t()`, and it's a closure of two arguments:

* Operation name. It is an atom, one of `:view`, `:update`, `:force_update`, `:delete`, `:inpsect`
* Operation arguments. It is a tuple which size depends on an operation

Currently every path-closure has 5 operations:
```elixir
path_closure =
  fn
    # Operation which gets value from structure and return `function.(value)`
    :view,         {structure, hook_function} -> ...

    # Operation which returns new structure with updated value
    :update,       {structure, hook_function} -> ...

    # Operation which returns new structure with updated value, or default set
    :force_update, {structure, hook_function, default} -> ...

    # Operation which returns new structure with deleted value.
    :delete,       {structure, delete_function} -> ...

    # Inspects the path. Returns Elixir's AST. This is used only for error-logging and debugging
    :inspect,      _ -> ...
  end
```

Here `structure` is the structure which is viewed or updated by this path and `hook_function` or `delete_function` is a hook function described in the next section. If the value in the structure defined by the path is not present, path-closure **must** return `:error`. If it's present, path-closure must return whatever is returned by `hook_function(value)`

## Hook function

You can see that for every operation except `inspect` accepts some function as a second argument. This function is called a hook function and it **must be called** on the value from the `structure` defined by the path (if the value is present). Hook function is required to 

### Return types

Here `function` returns `{:ok, result} | :error`  
And `delete_function` returns `{:ok, result} | :error | :delete_me`

* `{:ok, result}` returns updated value for update/force_update/delete operations and value to be returned for `view`
* `:error` in case function call has not succeeded
* `:delete_me` is returned by function **only** for `:delete` operation clause. It means that the value upon which the hook function was called must be deleted. For all other clauses, this must be treated as an invalid hook function and error **must** be raised

## Qualities

Special requirements are described here

* Path-closure **must not** raise or throw if it's called with correct operation and argument tuple

* Path-closure **must** be idempotent. This means that path-closure must return the same result for the same inputs every time it's called.

* Path-closure **should** not produce any side-effects. Thought it actually can produce side-effects, you shouldn't count on them.
