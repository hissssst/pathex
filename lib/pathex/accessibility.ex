defmodule Pathex.Accessibility do

  @moduledoc """
  Helpers to create paths from `Access.t()` and lists

  > Note:  
  > This module is separate because functions presented in this module
  > are suboptimal. You should try use `Pathex.path/2` first, and only
  > if its not applicable to you use-case, you should use functions
  > from this module
  """

  import Pathex

  defmacrop wrap(do: code) do
    quote do
      try do
        unquote(code)
      rescue
        _ -> :error
      end
    end
  end

  @doc """
  Converts path-closure to `Access.t()`

  Example:
      iex> import Pathex
      iex> access = to_access path(:x / 0, :map)
      iex> 1 = get_in(%{x: %{0 => 1}}, access)
  """
  @doc export: true
  def to_access(path_closure) do
    List.wrap fn
      :get, data, next ->
        case at(data, path_closure, next) do
          {:ok, res} -> res
          :error -> nil
        end

      :get_and_update, data, next ->
        case view(data, path_closure) do
          {:ok, res} ->
            case next.(res) do
              :pop ->
                case delete(data, path_closure) do
                  {:ok, deleted} -> {res, deleted}
                  :error -> {nil, data}
                end

              {get, update} ->
                case set(data, path_closure, update) do
                  {:ok, res} -> {get, res}
                  :error -> {nil, data}
                end
            end

          :error ->
            {nil, data}
        end
    end
  end

  @doc """
  Creates path-closure from `Access.t()`.

  > Note:
  > Paths created using this function do not support force operations yet

  Example:
      iex> import Pathex
      iex> p = from_access [:x, :y]
      iex> 10 = view!(%{x: [y: 10]}, p)
  """
  @doc export: true
  def from_access(access) do
    fn
      :view, {data, func} ->
        wrap do
          case get_in(data, access) do
            nil -> :error
            res -> func.(res)
          end
        end

      :update, {data, func} ->
        wrap do
          case get_in(data, access) do
            nil -> :error
            res ->
              with {:ok, res} <- func.(res) do
                {:ok, put_in(data, access, res)}
              end
          end
        end

      :force_update, _ ->
        IO.warn "Force update is not implemented for lenses created using access"
        :error

      :delete, {data, func} ->
        wrap do
          case get_in(data, access) do
            nil -> :error
            res ->
              case func.(res) do
                :delete_me ->
                  {:ok, elem(pop_in(data, access), 1)}

                {:ok, new_value} ->
                  {:ok, put_in(data, access, new_value)}

                :error ->
                  :error
              end
          end
        end

      :inspect, _ ->
        {:accessible, [], [access]}
    end
  end

  # Here is some code generation for from list function
  @doc """
  Creates path from list of items. The list of items should not be known
  at runtime, therefore some optimizations of paths are not possible. Use this
  function only when `Pathex.path/2` is not applicable

  Example:
      iex> import Pathex
      iex> p = from_list [:x, 1, :y]
      iex> 10 = view!(%{x: [1, [y: 10]]}, p)
  """
  @doc export: true

  # Create header with default value for `mod`
  def from_list(list, mod \\ :naive)

  # Generate implementation for non-empty lists with given mod
  for mod <- ~w[naive json map]a do
    def from_list([head | tail], unquote(mod)) do
      Enum.reduce(tail, path(head, unquote(mod)), fn right, left ->
        left ~> path(right, unquote(mod))
      end)
    end
  end

  # Implementation for empty list
  def from_list([], _) do
    import Pathex.Lenses
    matching(_)
  end
end
