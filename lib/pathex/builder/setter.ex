defmodule Pathex.Builder.Setter do
  # Module with common functions for updaters
  @moduledoc false

  alias Pathex.Builder.Code, as: BuilderCode
  alias Pathex.Combination
  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  # Helpers

  # Non variable
  @spec create_setter(Combination.pair(), Macro.t()) :: Macro.t()
  def create_setter({:map, key}, tail) do
    pinned = pin(key)

    quote do
      %{unquote(pinned) => value} = map ->
        %{map | unquote(key) => value |> unquote(tail)}
    end
  end

  def create_setter({:list, index}, tail) when is_integer(index) do
    x = {:x, [], Elixir}
    match = list_match(index, x)

    quote do
      unquote(match) = list ->
        List.replace_at(list, unquote(index), unquote(x) |> unquote(tail))
    end
  end

  def create_setter({:tuple, index}, tail) when is_integer(index) do
    indexplusone = index + 1

    quote do
      t when is_tuple(t) and tuple_size(t) > unquote(index) ->
        val =
          unquote(indexplusone)
          |> :erlang.element(t)
          |> unquote(tail)

        :erlang.setelement(unquote(indexplusone), t, val)
    end
  end

  def create_setter({:keyword, key}, tail) when is_atom(key) do
    quote do
      [{a, _} | _] = keyword when is_atom(a) ->
        unquote(__MODULE__).keyword_update(keyword, unquote(key), fn x ->
          x |> unquote(tail)
        end)
    end
  end

  # Variable

  def create_setter({:list, index}, tail) when is_var(index) do
    quote do
      list when is_list(list) and is_integer(unquote(index)) ->
        if abs(unquote(index)) > length(list) do
          throw(:path_not_found)
        else
          List.update_at(list, unquote(index), fn x -> x |> unquote(tail) end)
        end
    end
  end

  def create_setter({:tuple, index}, tail) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) > unquote(index) ->
        indexplusone = unquote(index) + 1

        val =
          indexplusone
          |> :erlang.element(tuple)
          |> unquote(tail)

        :erlang.setelement(indexplusone, tuple, val)
    end
  end

  def create_setter({:keyword, key}, tail) when is_var(key) do
    quote do
      keyword when is_list(keyword) and is_atom(unquote(key)) ->
        unquote(__MODULE__).keyword_update(keyword, unquote(key), fn x ->
          x |> unquote(tail)
        end)
    end
  end

  @spec fallback() :: Macro.t()
  def fallback do
    quote do
      _ -> throw(:path_not_found)
    end
  end

  @spec wrap_to_code(Macro.t(), [Macro.t()]) :: BuilderCode.t()
  def wrap_to_code(code, [arg1 | _] = args) do
    code =
      quote do
        try do
          {:ok, unquote(arg1) |> unquote(code)}
        catch
          :path_not_found -> :error
        end
      end

    %BuilderCode{code: code, vars: args}
  end

  @spec keyword_update(Keyword.t(), atom(), (any() -> any())) :: Keyword.t()
  def keyword_update(keyword, key, func)
  def keyword_update([], _, _), do: throw(:path_not_found)

  def keyword_update([{key, value} | tail], key, func) do
    new_value = func.(value)
    [{key, new_value} | tail]
  end

  def keyword_update([item | tail], key, func) do
    [item | keyword_update(tail, key, func)]
  end

  # def keyword_update(keyword, key, func, head_acc \\ [])
  # def keyword_update([], _, _, _), do: throw(:path_not_found)
  # def keyword_update([{key, value} | tail], key, func, head_acc) do
  #   new_value = func.(value)
  #   :lists.reverse(head_acc) ++ [{key, new_value} | tail]
  # end
  # def keyword_update([item | tail], key, func, head_acc) do
  #   keyword_update(tail, key, func, [item | head_acc])
  # end
end
