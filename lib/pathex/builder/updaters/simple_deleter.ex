defmodule Pathex.Builder.SimpleDeleter do
  # Generates deleter for naive paths
  @moduledoc false

  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  alias Pathex.Builder.Setter
  alias Pathex.Common
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}

  def build(combination) do
    [last | tail] = Enum.reverse(combination)

    tail
    |> Enum.reduce(initial(last), &reduce_into/2)
    |> Setter.wrap_to_code([@structure_variable])
  end

  defp reduce_into(path_items, acc) do
    setters = Enum.flat_map(path_items, &Setter.create_setter(&1, acc))
    Common.to_case(setters ++ fallback())
  end

  defp initial(last_path) do
    last_path
    |> Enum.flat_map(&create_deleter(&1))
    |> Kernel.++(fallback())
    |> Common.to_case()
  end

  # For valiable and non variable

  defp create_deleter({:map, key}) do
    pinned = pin(key)

    quote do
      %{unquote(pinned) => value} = map ->
        Map.delete(map, unquote(key))
    end
  end

  # Non variable

  defp create_deleter({:list, index}) when is_integer(index) do
    x = {:_, [], Elixir}
    match = list_match(index, x)

    quote do
      unquote(match) = list ->
        List.delete_at(list, unquote(index))
    end
  end

  defp create_deleter({:tuple, index}) when is_integer(index) do
    indexplusone = index + 1

    quote do
      t when is_tuple(t) and tuple_size(t) > unquote(index) ->
        :erlang.delete_element(unquote(indexplusone), t)
    end
  end

  defp create_deleter({:keyword, key}) when is_atom(key) do
    quote do
      [{_, _} | _] = keyword ->
        case Keyword.fetch(keyword, unquote(key)) do
          {:ok, value} -> Keyword.delete(keyword, unquote(key))
          :error -> throw(:path_not_found)
        end
    end
  end

  # Variable

  defp create_deleter({:list, index}) when is_var(index) do
    quote do
      list when is_list(list) and is_integer(unquote(index)) ->
        if abs(unquote(index)) > length(list) do
          throw(:path_not_found)
        else
          List.delete_at(list, unquote(index))
        end
    end
  end

  defp create_deleter({:tuple, index}) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) > unquote(index) ->
        :erlang.delete_element(unquote(index) + 1, tuple)
    end
  end

  defp create_deleter({:keyword, key}) when is_var(key) do
    quote do
      [{_, _} | _] = keyword when is_atom(unquote(key)) ->
        case Keyword.fetch(keyword, unquote(key)) do
          {:ok, value} -> Keyword.delete(keyword, unquote(key))
          :error -> throw(:path_not_found)
        end
    end
  end

  def fallback do
    quote do
      _ -> throw(:path_not_found)
    end
  end

  # Setters

  # For valiable and non variable

  # def create_setter({:map, key}, tail) do
  #   pinned = pin(key)

  #   quote do
  #     %{unquote(pinned) => value} = map ->
  #       {popped, new_value} = value |> unquote(tail)
  #       {popped, %{map | unquote(key) => new_value}}
  #   end
  # end

  # # Non variable

  # def create_setter({:list, index}, tail) when is_integer(index) do
  #   x = {:x, [], Elixir}
  #   match = list_match(index, x)

  #   quote do
  #     unquote(match) = list ->
  #       {popped, new_value} = unquote(x) |> unquote(tail)
  #       {popped, List.replace_at(list, unquote(index), new_value)}
  #   end
  # end

  # def create_setter({:tuple, index}, tail) when is_integer(index) do
  #   quote do
  #     t when is_tuple(t) and tuple_size(t) > unquote(index) ->
  #       {popped, val} =
  #         elem(t, unquote(index))
  #         |> unquote(tail)

  #       {popped, put_elem(t, unquote(index), val)}
  #   end
  # end

  # def create_setter({:keyword, key}, tail) when is_atom(key) do
  #   quote do
  #     [{_, _} | _] = keyword ->
  #       case Keyword.fetch(keyword, unquote(key)) do
  #         {:ok, value} ->
  #           {popped, new_value} = value |> unquote(tail)
  #           {popped, Keyword.put(keyword, unquote(key), new_value)}

  #         :error ->
  #           throw(:path_not_found)
  #       end
  #   end
  # end

  # # Variable

  # def create_setter({:list, index}, tail) when is_var(index) do
  #   quote do
  #     l when is_list(l) and is_integer(unquote(index)) ->
  #       if abs(unquote(index)) > length(l) do
  #         throw(:path_not_found)
  #       else
  #         {popped, new_value} = :lists.nth(unquote(index) + 1, l) |> unquote(tail)
  #         {popped, List.replace_at(l, unquote(index), new_value)}
  #       end
  #   end
  # end

  # def create_setter({:tuple, index}, tail) when is_var(index) do
  #   quote do
  #     t
  #     when is_tuple(t) and is_integer(unquote(index)) and
  #            unquote(index) >= 0 and
  #            tuple_size(t) > unquote(index) ->
  #       {popped, val} =
  #         elem(t, unquote(index))
  #         |> unquote(tail)

  #       {popped, put_elem(t, unquote(index), val)}
  #   end
  # end

  # def create_setter({:keyword, key}, tail) when is_var(key) do
  #   quote do
  #     [{_, _} | _] = keyword when is_atom(unquote(key)) ->
  #       case Keyword.fetch(keyword, unquote(key)) do
  #         {:ok, value} ->
  #           {popped, new_value} = value |> unquote(tail)
  #           {popped, Keyword.put(keyword, unquote(key), new_value)}

  #         :error ->
  #           throw(:path_not_found)
  #       end
  #   end
  # end
end
