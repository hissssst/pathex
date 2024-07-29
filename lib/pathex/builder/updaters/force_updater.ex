defmodule Pathex.Builder.ForceUpdater do
  # Forceupdater-builder which builds function for updates in given path
  @moduledoc false

  alias Pathex.Common
  import Common, only: [is_var: 1]
  import Pathex.Builder.Setter, except: [create_updater: 3]
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @default_variable {:default, [], Elixir}
  @function_variable {:function, [], Elixir}

  @doc """
  Returns three argument code structure
  """
  @impl Pathex.Builder
  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> elem(0)
    |> wrap_to_code([@structure_variable, @function_variable, @default_variable])
  end

  defp reduce_into([path_item | _] = path_items, {acc_code, acc_items}) do
    fallback = fallback_from_acc(path_items, acc_items)
    setters = Enum.flat_map(path_items, &create_updater(&1, acc_code, acc_items))
    acc_items = add_to_acc(path_item, acc_items)
    {Common.to_case(setters ++ fallback ++ absolute_fallback()), acc_items}
  end

  defp initial do
    setfunc =
      quote do
        unquote(@function_variable).()
        |> case do
          {:ok, value} -> value
          :error -> throw(:path_not_found)
        end
      end

    {setfunc, @default_variable}
  end

  defp create_updater({:keyword, key}, tail, default) when is_var(key) do
    quote do
      keyword when is_list(keyword) and is_atom(unquote(key)) ->
        Keyword.update(keyword, unquote(key), unquote(default), fn val ->
          val |> unquote(tail)
        end)
    end
  end

  defp create_updater({:keyword, key}, tail, default) when is_atom(key) do
    quote do
      keyword when is_list(keyword) ->
        Keyword.update(keyword, unquote(key), unquote(default), fn val ->
          val |> unquote(tail)
        end)
    end
  end

  defp create_updater({:list, -1}, _tail, acc_items) do
    quote do
      list when is_list(list) ->
        [unquote(acc_items) | list]
    end
  end

  defp create_updater({:list, index}, tail, acc_items) when is_var(index) do
    quote do
      list when is_list(list) and unquote(index) == -1 ->
        [unquote(acc_items) | list]

      list when is_list(list) and is_integer(unquote(index)) and unquote(index) < 0 ->
        length = length(list)

        if -unquote(index) > length do
          len = max(-unquote(index) - 1 - length, 0)
          [unquote(acc_items) | List.duplicate(nil, len)] ++ list
        else
          List.update_at(list, unquote(index), fn x -> x |> unquote(tail) end)
        end

      list when is_list(list) and is_integer(unquote(index)) ->
        length = length(list)

        if unquote(index) > length do
          len = max(unquote(index) - length, 0)
          list ++ List.duplicate(nil, len) ++ [unquote(acc_items)]
        else
          List.update_at(list, unquote(index), fn x -> x |> unquote(tail) end)
        end
    end
  end

  defp create_updater({:tuple, index}, tail, acc_items) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) <= unquote(index) ->
        len = max(unquote(index) - tuple_size(tuple), 0)
        List.to_tuple(Tuple.to_list(tuple) ++ List.duplicate(nil, len) ++ [unquote(acc_items)])

      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) < 0 and
             tuple_size(tuple) < -unquote(index) ->
        len = max(-unquote(index) - tuple_size(tuple) - 1, 0)
        List.to_tuple([unquote(acc_items) | List.duplicate(nil, len)] ++ Tuple.to_list(tuple))

      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) < 0 ->
        index = tuple_size(tuple) + unquote(index) + 1
        val = :erlang.element(index, tuple) |> unquote(tail)
        :erlang.setelement(index, tuple, val)

      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 ->
        indexplusone = unquote(index) + 1

        val =
          indexplusone
          |> :erlang.element(tuple)
          |> unquote(tail)

        :erlang.setelement(indexplusone, tuple, val)
    end
  end

  defp create_updater(path_item, tail, _) do
    create_updater(path_item, tail)
  end

  defp add_to_acc({:map, item}, acc_items) do
    quote(do: %{unquote(item) => unquote(acc_items)})
  end

  defp add_to_acc({:keyword, item}, acc_items) do
    quote(do: [{unquote(item), unquote(acc_items)}])
  end

  defp add_to_acc({type, 0}, acc_items) do
    collection(type, [acc_items])
  end

  defp add_to_acc({type, -1}, acc_items) do
    collection(type, [acc_items])
  end

  defp add_to_acc({type, n}, acc_items) when is_integer(n) and n > 0 do
    nils = for _ <- 1..n, do: nil
    collection(type, nils ++ [acc_items])
  end

  defp add_to_acc({type, n}, acc_items) when is_integer(n) and n < 0 do
    nils = for _ <- 1..(-n), do: nil
    collection(type, [acc_items | nils])
  end

  defp add_to_acc({:list, var}, acc_items) do
    quote do
      case unquote(var) do
        0 ->
          [unquote(acc_items)]

        n when is_integer(n) ->
          for(_ <- 1..abs(n), do: nil) ++ [unquote(acc_items)]
      end
    end
  end

  defp add_to_acc({:tuple, var}, acc_items) do
    quote do
      case unquote(var) do
        0 ->
          {unquote(acc_items)}

        n when is_integer(n) ->
          List.to_tuple(List.duplicate(nil, n) ++ [unquote(acc_items)])
      end
    end
  end

  defp fallback_from_acc(path_items, acc) do
    Enum.flat_map(path_items, &gen_fallback(&1, acc))
  end

  defp gen_fallback({:map, key}, acc) do
    quote do
      %{} = other -> Map.put(other, unquote(key), unquote(acc))
    end
  end

  defp gen_fallback({:list, -1}, acc) do
    quote do
      l when is_list(l) ->
        [unquote(acc) | l]
    end
  end

  defp gen_fallback({:list, n}, acc) when is_integer(n) and n < 0 do
    quote do
      l when is_list(l) ->
        len = max(unquote(-n - 1) - length(l), 0)
        [unquote(acc) | List.duplicate(nil, len)] ++ l
    end
  end

  defp gen_fallback({:list, n}, acc) when is_integer(n) do
    quote do
      l when is_list(l) ->
        len = max(unquote(n) - length(l), 0)
        l ++ List.duplicate(nil, len) ++ [unquote(acc)]
    end
  end

  defp gen_fallback({:list, n}, acc) do
    quote do
      l when is_list(l) and unquote(n) == -1 ->
        [unquote(acc) | l]

      l when is_list(l) and is_integer(unquote(n)) and unquote(n) >= 0 ->
        len = max(unquote(n) - length(l), 0)
        l ++ List.duplicate(nil, len) ++ [unquote(acc)]

      l when is_list(l) and is_integer(unquote(n)) ->
        len = max(-unquote(n) - 1 - length(l), 0)
        [unquote(acc) | List.duplicate(nil, len)] ++ l
    end
  end

  defp gen_fallback({:tuple, n}, acc) when is_integer(n) and n >= 0 do
    quote do
      t when is_tuple(t) ->
        len = unquote(n) - tuple_size(t)
        List.to_tuple(Tuple.to_list(t) ++ List.duplicate(nil, len) ++ [unquote(acc)])
    end
  end

  defp gen_fallback({:tuple, n}, acc) when is_integer(n) and n < 0 do
    quote do
      t when is_tuple(t) ->
        len = -unquote(n) - tuple_size(t) - 1
        List.to_tuple([unquote(acc) | List.duplicate(nil, len)] ++ Tuple.to_list(t))
    end
  end

  defp gen_fallback({:tuple, n}, acc) do
    quote do
      t when is_tuple(t) and is_integer(unquote(n)) and unquote(n) >= 0 ->
        len = unquote(n) - tuple_size(t)
        List.to_tuple(Tuple.to_list(t) ++ List.duplicate(nil, len) ++ [unquote(acc)])

      t when is_tuple(t) and is_integer(unquote(n)) ->
        len = -unquote(n) - tuple_size(t) - 1
        List.to_tuple([unquote(acc) | List.duplicate(nil, len)] ++ Tuple.to_list(t))
    end
  end

  defp gen_fallback({:keyword, key}, acc) do
    quote do
      kwd when is_list(kwd) ->
        [{unquote(key), unquote(acc)} | kwd]
    end
  end

  defp absolute_fallback do
    quote do
      _ -> throw(:path_not_found)
    end
  end

  defp collection(:list, items) do
    quote do: [unquote_splicing(items)]
  end

  defp collection(:tuple, items) do
    quote do: {unquote_splicing(items)}
  end
end
