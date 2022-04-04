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
    quote do
      t when is_tuple(t) and tuple_size(t) > unquote(index) ->
        val =
          elem(t, unquote(index))
          |> unquote(tail)

        put_elem(t, unquote(index), val)
    end
  end

  def create_setter({:keyword, key}, tail) when is_atom(key) do
    quote do
      [{_, _} | _] = keyword ->
        if Keyword.has_key?(keyword, unquote(key)) do
          Keyword.update!(keyword, unquote(key), fn val ->
            val |> unquote(tail)
          end)
        else
          throw(:path_not_found)
        end
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
        val =
          elem(t, unquote(index))
          |> unquote(tail)

        put_elem(t, unquote(index), val)
    end
  end

  def create_setter({:keyword, key}, tail) when is_var(key) do
    quote do
      [{_, _} | _] = keyword when is_atom(unquote(key)) ->
        if Keyword.has_key?(keyword, unquote(key)) do
          Keyword.update!(keyword, unquote(key), fn val ->
            val |> unquote(tail)
          end)
        else
          throw(:path_not_found)
        end
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
end
