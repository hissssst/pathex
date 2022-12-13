defmodule Pathex.Short do
  @moduledoc """
  This module provides short definitions of pathex paths.

  For example, when using `Pathex.Short`, you can transform this
  ```elixir
  path :x / :y / 1 / 2
  ```

  To just this
  ```elixir
  :x / :y / 1 / 2
  ```
  """

  import Kernel, except: [/: 2]
  require Pathex

  defmacro __using__(opts \\ []) do
    quote do
      import Kernel, except: [/: 2]
      import Pathex.Short

      use(Pathex, unquote(opts))
    end
  end

  @doc """
  This macro redefines `/` operator, so use this macro with caution
  or only in bounded context (for example, you can `use Pathex.Short` only
  inside functions)

  ## Example

      iex> use Pathex.Short
      iex> path = :x / :y
      iex> 1 = Pathex.view!(%{x: %{y: 1}}, path)
  """
  defmacro l / r do
    quote do
      Pathex.path(unquote(l) / unquote(r))
    end
    |> Macro.expand_once(__CALLER__)
  end
end
