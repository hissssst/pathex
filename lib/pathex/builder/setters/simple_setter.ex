defmodule Pathex.Builder.SimpleSetter do

  import Pathex.Builder, only: [list_match: 2, pin: 1]

  @first_arg {:first_arg, [], Elixir}
  @initial {:value_to_set, [], Elixir}

  def build(combination) do
    code =
      combination
      |> Enum.reverse()
      |> Enum.reduce(initial(), &reduce_into/2)

    code =
      quote do
        try do
          {:ok, unquote(@first_arg) |> unquote(code)}
        catch
          :path_not_found -> {:error, unquote(@first_arg)}
        end
      end

    %Pathex.Builder.Code{code: code, vars: [@first_arg, @initial]}
  end

  defp reduce_into(path_items, acc) do
    setters = Enum.flat_map(path_items, & create_setter(&1, acc))
    {:case, [], [[do: setters ++ fallback()]]}
  end

  defp create_setter({:map, key}, tail) do
    pinned = pin(key)
    quote do
      %{unquote(pinned) => value} = map ->
        %{map | unquote(key) => value |> unquote(tail)}
    end
  end
  defp create_setter({:list, index}, tail) do
    x = {:x, [], Elixir}
    match = list_match(index, x)
    quote do
      unquote(match) = list ->
        List.replace_at(list, unquote(index), unquote(x) |> unquote(tail))
    end
  end
  defp create_setter({:tuple, index}, tail) do
    quote do
      t when is_tuple(t) ->
        val =
          elem(t, unquote(index))
          |> unquote(tail)
        put_elem(t, unquote(index), val)
    end
  end
  defp create_setter({:keyword, key}, tail) do
    quote do
      [{_, _} | _] = keyword ->
        Keyword.update!(keyword, unquote(key), fn val ->
          val |> unquote(tail)
        end)
    end
  end

  defp initial do
    quote do
      (fn _ -> unquote(@initial) end).()
    end
  end

  defp fallback do
    quote do
      _ -> throw :path_not_found
    end
  end

end
