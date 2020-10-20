# Path

This page describes what a `Pathex.t()` is and how to create and use one

## Basic

* Create: As described in [README](README.md) and `Pathex` simple paths can be created with
`Pathex.path/2` and `Pathex.sigil_P/2` macroses

* Use: This paths then can be called using macro-helpers from `Pathex` like `Pathex.view/2` or `Pathex.force_set/3`

* Prebuilt: some non-trivial prebuilt lenses are avaliable in `Pathex.Lenses` module

## Internal representation

Every path-closure is a closure of two arguments:
* Operation name (atom)
* Operation arguments, tuple which size depends on an operation

Currently every path-closure has 3 operations:
```elixir
path_closure =
  fn
    # Operation which gets value from structure and retuns `function.(value)`
    :view,         {structure, function} -> ...

    # Operation which returns new structure with updated value
    :update,       {structure, function} -> ...

    # Operation which returns new structure with updated value, or default set
    :force_update, {structure, function, default} -> ...
  end
```

Path-closure must return `{:ok, any()} | :error` for every valid operation call
and raise if non-exsisting operation is called

Path-closures create by `Pathex.path/2` or `Pathex.sigil_P/2` are totally pure functions
with no side effects
