defmodule Pathex.Builder.Setter do

  @moduledoc """
  Module with common functions for setters
  """

  import Pathex.Common, only: [list_match: 2, pin: 1]

  @callback build(Pathex.Combination.t()) :: Pathex.Builder.Code.t()

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
        Keyword.update!(keyword, unquote(key), fn val ->
          val |> unquote(tail)
        end)
    end
  end

  # Variable
  def create_setter({:list, {_, _, _} = index}, tail) do
    quote do
      l when is_list(l) ->
        List.update_at(l, unquote(index), fn x -> x |> unquote(tail) end)
    end
  end
  def create_setter({:tuple, {_, _, _} = index}, tail) do
    quote do
      t when is_tuple(t) and is_integer(unquote(index))
        and unquote(index) >= 0
        and tuple_size(t) > unquote(index) ->
        val =
          elem(t, unquote(index))
          |> unquote(tail)
        put_elem(t, unquote(index), val)
    end
  end
  def create_setter({:keyword, {_, _, _} = key}, tail) do
    quote do
      [{_, _} | _] = keyword when is_atom(unquote(key)) ->
        Keyword.update!(keyword, unquote(key), fn val ->
          val |> unquote(tail)
        end)
    end
  end

  def fallback do
    quote do
      _ -> throw :path_not_found
    end
  end

  def wrap_to_code(code, arg1, arg2) do
    code =
      quote do
        try do
          {:ok, unquote(arg1) |> unquote(code)}
        catch
          :path_not_found -> {:error, unquote(arg1)}
        end
      end

    %Pathex.Builder.Code{code: code, vars: [arg1, arg2]}
  end

end
