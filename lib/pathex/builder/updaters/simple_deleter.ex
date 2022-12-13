defmodule Pathex.Builder.SimpleDeleter do
  # Generates deleter for naive paths
  @moduledoc false

  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  alias Pathex.Builder.Setter
  alias Pathex.Common
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  @impl Pathex.Builder
  def build(combination) do
    [last | tail] = Enum.reverse(combination)

    tail
    |> Enum.reduce(initial(last), &reduce_into/2)
    |> Setter.wrap_to_code([@structure_variable, @function_variable])
  end

  defp reduce_into(path_items, acc) do
    setters = Enum.flat_map(path_items, &Setter.create_updater(&1, acc))
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
    quote do
      %{unquote(pin(key)) => value} = map ->
        case unquote(@function_variable).(value) do
          {:ok, new_value} ->
            %{map | unquote(key) => new_value}

          :delete_me ->
            Map.delete(map, unquote(key))

          :error ->
            throw(:path_not_found)
        end
    end
  end

  # Non variable

  defp create_deleter({:list, index}) when is_integer(index) and index >= 0 do
    x = {:x, [], Elixir}
    match = list_match(index, x)

    quote do
      unquote(match) = list ->
        case unquote(@function_variable).(:lists.nth(unquote(index + 1), list)) do
          {:ok, new_value} ->
            List.replace_at(list, unquote(index), new_value)

          :delete_me ->
            List.delete_at(list, unquote(index))

          :error ->
            throw(:path_not_found)
        end
    end
  end

  defp create_deleter({:list, index}) when is_integer(index) and index < 0 do
    quote do
      list when is_list(list) ->
        index = length(list) + unquote(index)

        if index < 0 do
          throw(:path_not_found)
        else
          case unquote(@function_variable).(:lists.nth(index + 1, list)) do
            {:ok, new_value} ->
              List.replace_at(list, unquote(index), new_value)

            :delete_me ->
              List.delete_at(list, unquote(index))

            :error ->
              throw(:path_not_found)
          end
        end
    end
  end

  defp create_deleter({:tuple, index}) when is_integer(index) and index >= 0 do
    quote do
      tuple when is_tuple(tuple) and tuple_size(tuple) > unquote(index) ->
        index = unquote(index + 1)

        case unquote(@function_variable).(:erlang.element(index, tuple)) do
          {:ok, new_value} ->
            :erlang.setelement(index, tuple, new_value)

          :delete_me ->
            :erlang.delete_element(index, tuple)

          :error ->
            throw(:path_not_found)
        end
    end
  end

  defp create_deleter({:tuple, index}) when is_integer(index) and index < 0 do
    quote do
      tuple when is_tuple(tuple) and tuple_size(tuple) >= -unquote(index) ->
        index = tuple_size(tuple) + unquote(1 + index)

        case unquote(@function_variable).(:erlang.element(index, tuple)) do
          {:ok, new_value} ->
            :erlang.setelement(index, tuple, new_value)

          :delete_me ->
            :erlang.delete_element(index, tuple)

          :error ->
            throw(:path_not_found)
        end
    end
  end

  defp create_deleter({:keyword, key}) when is_atom(key) do
    keyword = {:keyword, [], nil}
    body = keyword_body(keyword, key)

    quote do
      unquote(keyword) when is_list(unquote(keyword)) ->
        unquote(body)
    end
  end

  # Variable

  defp create_deleter({:list, index}) when is_var(index) do
    quote do
      list when is_list(list) and is_integer(unquote(index)) and unquote(index) >= 0 ->
        if unquote(index) >= length(list) do
          throw(:path_not_found)
        else
          case unquote(@function_variable).(:lists.nth(unquote(index) + 1, list)) do
            {:ok, new_value} ->
              List.replace_at(list, unquote(index), new_value)

            :delete_me ->
              List.delete_at(list, unquote(index))

            :error ->
              throw(:path_not_found)
          end
        end

      list when is_list(list) and is_integer(unquote(index)) and unquote(index) < 0 ->
        index = length(list) + unquote(index)

        if index < 0 do
          throw(:path_not_found)
        else
          case unquote(@function_variable).(:lists.nth(index + 1, list)) do
            {:ok, new_value} ->
              List.replace_at(list, index, new_value)

            :delete_me ->
              List.delete_at(list, index)

            :error ->
              throw(:path_not_found)
          end
        end
    end
  end

  defp create_deleter({:tuple, index}) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) > unquote(index) ->
        index = unquote(index) + 1

        case unquote(@function_variable).(:erlang.element(index, tuple)) do
          {:ok, new_value} ->
            :erlang.setelement(index, tuple, new_value)

          :delete_me ->
            :erlang.delete_element(index, tuple)

          :error ->
            throw(:path_not_found)
        end

      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) < 0 and
             tuple_size(tuple) >= -unquote(index) ->
        index = tuple_size(tuple) + unquote(index) + 1

        case unquote(@function_variable).(:erlang.element(index, tuple)) do
          {:ok, new_value} ->
            :erlang.setelement(index, tuple, new_value)

          :delete_me ->
            :erlang.delete_element(index, tuple)

          :error ->
            throw(:path_not_found)
        end
    end
  end

  defp create_deleter({:keyword, key}) when is_var(key) do
    keyword = {:keyword, [], nil}
    body = keyword_body(keyword, key)

    quote do
      [{_, _} | _] = unquote(keyword) when is_atom(unquote(key)) ->
        unquote(body)
    end
  end

  defp fallback do
    quote do
      _ -> throw(:path_not_found)
    end
  end

  defp keyword_body(keyword, key) do
    quote do
      unquote(__MODULE__).keyword_update(
        unquote(keyword),
        unquote(key),
        unquote(@function_variable)
      )
    end
  end

  @spec keyword_update(Keyword.t(), atom(), (any() -> any())) :: Keyword.t()
  def keyword_update(keyword, key, func)
  def keyword_update([], _, _), do: throw(:path_not_found)

  def keyword_update([{key, value} | tail], key, func) do
    case func.(value) do
      {:ok, new_value} ->
        [{key, new_value} | tail]

      :error ->
        throw(:path_not_found)

      :delete_me ->
        tail
    end
  end

  def keyword_update([item | tail], key, func) do
    [item | keyword_update(tail, key, func)]
  end

  # Setters

  # For valiable and non variable

  # def create_updater({:map, key}, tail) do
  #   pinned = pin(key)

  #   quote do
  #     %{unquote(pinned) => value} = map ->
  #       {popped, new_value} = value |> unquote(tail)
  #       {popped, %{map | unquote(key) => new_value}}
  #   end
  # end

  # # Non variable

  # def create_updater({:list, index}, tail) when is_integer(index) do
  #   x = {:x, [], Elixir}
  #   match = list_match(index, x)

  #   quote do
  #     unquote(match) = list ->
  #       {popped, new_value} = unquote(x) |> unquote(tail)
  #       {popped, List.replace_at(list, unquote(index), new_value)}
  #   end
  # end

  # def create_updater({:tuple, index}, tail) when is_integer(index) do
  #   quote do
  #     t when is_tuple(t) and tuple_size(t) > unquote(index) ->
  #       {popped, val} =
  #         elem(t, unquote(index))
  #         |> unquote(tail)

  #       {popped, put_elem(t, unquote(index), val)}
  #   end
  # end

  # def create_updater({:keyword, key}, tail) when is_atom(key) do
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

  # def create_updater({:list, index}, tail) when is_var(index) do
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

  # def create_updater({:tuple, index}, tail) when is_var(index) do
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

  # def create_updater({:keyword, key}, tail) when is_var(key) do
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
