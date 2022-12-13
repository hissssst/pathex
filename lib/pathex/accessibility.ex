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

  @type access :: nonempty_list(term())

  @doc """
  Converts path-closure to `Access.t()`

  ## Example

      iex> import Pathex
      iex> access = to_access path(:x / 0, :map)
      iex> 1 = get_in(%{x: %{0 => 1}}, access)
  """
  @doc export: true
  @spec to_access(Pathex.t()) :: [Access.access_fun(any(), any())]
  def to_access(path_closure) do
    List.wrap(fn
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
    end)
  end

  @doc """
  Creates path-closure from `Access.t()`.

  > Note:
  > Paths created using this function do not support force operations yet

  ## Example

      iex> import Pathex
      iex> p = from_access [:x, :y]
      iex> 10 = view!(%{x: [y: 10]}, p)
  """
  @doc export: true
  @spec from_access(access()) :: Pathex.t()
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
            nil ->
              :error

            res ->
              with {:ok, res} <- func.(res) do
                {:ok, put_in(data, access, res)}
              end
          end
        end

      :force_update, _ ->
        IO.warn("Force update is not implemented for lenses created using access")
        :error

      :delete, {data, func} ->
        wrap do
          case get_in(data, access) do
            nil ->
              :error

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

  ## Example

      iex> import Pathex
      iex> p = from_list [:x, 1, :y]
      iex> 10 = view!(%{x: [1, [y: 10]]}, p)
  """
  @doc export: true

  # Create header with default value for `mod`
  @spec from_list([any()], Pathex.mod()) :: Pathex.t()
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

  @doc """
  Creates a lens for specific key in the structure. It behaves the same way as a lens created
  with `Pathex.path/2` but it works only with specified structure and `force_set` creates
  a structure with default values.

  ## Example

      iex> require Pathex
      iex> defmodule User do
      ...>   defstruct name: "", age: nil
      ...> end
      iex> name_lens = from_struct(User, :name)
      iex> %{name: "Joe"} = Pathex.force_set!(%{}, name_lens, "Joe")
  """
  @spec from_struct(module(), atom()) :: Pathex.t(struct(), any())
  def from_struct(module, key) when is_atom(key) and is_atom(module) do
    # TODO move this runtime computation to compile-time with fallback to runtime implementation
    {required?, required, defaulted} = check_struct(module, key)
    reqlen = length(required)

    if required? do
      fn
        :view, {%^module{^key => value}, func} ->
          func.(value)

        :update, {%^module{^key => value} = structure, func} ->
          with {:ok, value} <- func.(value) do
            {:ok, %{structure | key => value}}
          end

        :delete, {_, _func} ->
          # Can't delete required
          :error

        :force_update, {%^module{^key => value} = structure, func, default} ->
          case func.(value) do
            {:ok, value} ->
              {:ok, %{structure | key => value}}

            :error ->
              {:ok, %{structure | key => default}}
          end

        :force_update, {%{} = map, func, default} ->
          value =
            with(
              %{^key => value} <- map,
              {:ok, value} <- func.(value)
            ) do
              value
            else
              _ -> default
            end

          map = Map.put(map, key, value)
          requireds = Map.take(map, required)

          if map_size(requireds) == reqlen do
            defaulteds = Map.take(map, defaulted)
            {:ok, struct(module, :maps.merge(defaulteds, requireds))}
          else
            :error
          end

        :inspect, _ ->
          {:from_struct, [],
           [{{:., [], [{:%, [], [module, {:%{}, [], []}]}, key]}, [no_parens: true], []}]}

        op, _ when op in ~w[inspect delete update view force_update]a ->
          :error
      end
    else
      default_in_struct =
        module
        |> struct([])
        |> Map.fetch!(key)

      fn
        :view, {%^module{^key => value}, func} ->
          func.(value)

        :update, {%^module{^key => value} = structure, func} ->
          with {:ok, value} <- func.(value) do
            {:ok, %{structure | key => value}}
          end

        :delete, {%^module{} = structure, _func} ->
          {:ok, %{structure | key => default_in_struct}}

        :force_update, {%^module{^key => value} = structure, func, default} ->
          case func.(value) do
            {:ok, value} ->
              {:ok, %{structure | key => value}}

            :error ->
              {:ok, %{structure | key => default}}
          end

        :force_update, {%{} = map, func, default} ->
          value =
            with(
              %{^key => value} <- map,
              {:ok, value} <- func.(value)
            ) do
              value
            else
              _ -> default
            end

          map = Map.put(map, key, value)
          requireds = Map.take(map, required)

          if map_size(requireds) == reqlen do
            defaulteds = Map.take(map, defaulted)
            {:ok, struct(module, :maps.merge(defaulteds, requireds))}
          else
            :error
          end

        :inspect, _ ->
          {:from_struct, [],
           [{{:., [], [{:%, [], [module, {:%{}, [], []}]}, key]}, [no_parens: true], []}]}

        op, _ when op in ~w[inspect delete update view force_update]a ->
          :error
      end
    end
  end

  defp check_struct(module, key) do
    do_split(module.__info__(:struct), [], [], nil, key)
  end

  defp do_split([%{field: key, required: true} | tail], required, defaulted, _, key) do
    do_split(tail, [key | required], defaulted, true, key)
  end

  defp do_split([%{field: key, required: false} | tail], required, defaulted, _, key) do
    do_split(tail, required, [key | defaulted], false, key)
  end

  defp do_split([%{field: field, required: true} | tail], required, defaulted, acc, key) do
    do_split(tail, [field | required], defaulted, acc, key)
  end

  defp do_split([%{field: field, required: false} | tail], required, defaulted, acc, key) do
    do_split(tail, required, [field | defaulted], acc, key)
  end

  defp do_split([], _, _, nil, key) do
    raise ArgumentError, message: "Key #{Kernel.inspect(key)} not found in structure keys"
  end

  defp do_split([], required, defaulted, acc, _), do: {acc, required, defaulted}

  @doc """
  Creates a lens from record macro.
  All arguments of this macro must be compile time atoms

  ## Example

      iex> require Pathex
      iex> defmodule User do
      ...>   import Record; defrecord(:user, name: "", age: nil)
      ...>
      ...>   def new(name) do
      ...>     name_lens = from_record(User, :user, :name)
      ...>     Pathex.force_set!({}, name_lens, name)
      ...>   end
      ...> end
      iex> {:user, "Joe", nil} = User.new("Joe")
  """
  defmacro from_record(module, macro, key) do
    module = Macro.expand(module, __CALLER__)
    macro = Macro.expand(macro, __CALLER__)
    key = Macro.expand(key, __CALLER__)

    unless is_atom(module) and is_atom(macro) and is_atom(key) do
      raise CompileError, message: "All arguments must be atoms at compile time"
    end

    valuevar = {:value, [counter: :erlang.unique_integer([:positive])], __MODULE__}
    recordvar = {:record, [counter: :erlang.unique_integer([:positive])], __MODULE__}
    defaultvar = {:default, [counter: :erlang.unique_integer([:positive])], __MODULE__}

    {requiral, record, keypattern, setkey} =
      if __CALLER__.module == module do
        {
          nil,
          Macro.expand(quote(do: unquote(macro)()), __CALLER__),
          Macro.expand(
            quote(do: unquote(macro)([{unquote(key), unquote(valuevar)}])),
            __CALLER__
          ),
          fn record, value ->
            Macro.expand(
              quote(do: unquote(macro)(unquote(record), [{unquote(key), unquote(value)}])),
              __CALLER__
            )
          end
        }
      else
        {
          quote(do: require(unquote(module))),
          quote(do: unquote(module).unquote(macro)()),
          quote(do: unquote(module).unquote(macro)([{unquote(key), unquote(valuevar)}])),
          fn record, value ->
            quote do:
                    unquote(module).unquote(macro)(unquote(record), [
                      {unquote(key), unquote(value)}
                    ])
          end
        }
      end

    quote generated: true do
      unquote(requiral)

      fn
        :view, {unquote(keypattern), func} ->
          func.(unquote(valuevar))

        :update, {unquote(keypattern) = unquote(recordvar), func} ->
          with {:ok, unquote(valuevar)} <- func.(unquote(valuevar)) do
            {:ok, unquote(setkey.(recordvar, valuevar))}
          end

        :force_update, {unquote(keypattern) = unquote(recordvar), func, unquote(defaultvar)} ->
          case func.(unquote(valuevar)) do
            {:ok, unquote(valuevar)} ->
              {:ok, unquote(setkey.(recordvar, valuevar))}

            :error ->
              {:ok, unquote(setkey.(recordvar, valuevar))}
          end

        :force_update, {t, _func, unquote(defaultvar)} when is_tuple(t) ->
          unquote(recordvar) = unquote(record)
          {:ok, unquote(setkey.(recordvar, defaultvar))}

        :delete, _ ->
          :error

        :inspect, _ ->
          {:from_record, [], [{{:., [], [unquote(module), unquote(macro)]}, [], [unquote(key)]}]}

        op, _ when op in ~w[inspect delete update view force_update]a ->
          :error
      end
    end

    # |> tap(fn x -> IO.puts Code.format_string! Macro.to_string x end)
  end
end
