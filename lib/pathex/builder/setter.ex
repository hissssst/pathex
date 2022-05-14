defmodule Pathex.Builder.Setter do
  # Module with common functions for updaters
  @moduledoc false

  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  # Helpers

  # Non variable
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
      l when is_list(l) and is_integer(unquote(index)) ->
        if abs(unquote(index)) > length(l) do
          throw(:path_not_found)
        else
          List.update_at(l, unquote(index), fn x -> x |> unquote(tail) end)
        end
    end
  end

  def create_setter({:tuple, index}, tail) when is_var(index) do
    quote do
      t
      when is_tuple(t) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(t) > unquote(index) ->
        indexplusone = unquote(index) + 1

        val =
          indexplusone
          |> :erlang.element(t)
          |> unquote(tail)

        :erlang.setelement(indexplusone, t, val)
    end
  end

  def create_setter({:keyword, key}, tail) when is_var(key) do
    quote do
      [{a, _} | _] = keyword when is_atom(unquote(key)) and is_atom(a) ->
        unquote(__MODULE__).keyword_update(keyword, unquote(key), fn x ->
          x |> unquote(tail)
        end)
    end
  end

  def fallback do
    quote do
      _ -> throw(:path_not_found)
    end
  end

  def wrap_to_code(code, [arg1 | _] = args) do
    code =
      quote do
        try do
          {:ok, unquote(arg1) |> unquote(code)}
        catch
          :path_not_found -> :error
        end
      end

    %Pathex.Builder.Code{code: code, vars: args}
  end

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
