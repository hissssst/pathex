defmodule Pathex.Builder.ForceSetter do

  import Pathex.Builder.Setter
  @behaviour Pathex.Builder.Setter

  @first_arg {:first_arg, [], Elixir}
  @initial {:value_to_set, [], Elixir}

  def build(combination) do
    combination
    |> Enum.reverse()
    |> Enum.reduce(initial(), &reduce_into/2)
    |> elem(0)
    |> wrap_to_code(@first_arg, @initial)
  end

  defp reduce_into([path_item | _] = path_items, {acc_code, acc_items}) do
    fallback = fallback_from_acc(path_items, acc_items)
    acc_items = add_to_acc(path_item, acc_items)
    setters = Enum.flat_map(path_items, & create_setter(&1, acc_code, acc_items))
    {{:case, [], [[do: setters ++ fallback]]}, acc_items}
  end

  defp initial do
    setfunc = quote(do: (fn _ -> unquote(@initial) end).())
    {setfunc, @initial}
  end

  defp create_setter({:keyword, key}, tail, {_, _, [{_, acc_items}]}) do
    quote do
      [{_, _} | _] = keyword ->
        Keyword.update(keyword, unquote(key), unquote(acc_items), fn val ->
          val |> unquote(tail)
        end)
    end
  end
  defp create_setter(path_item, tail, _) do
    create_setter(path_item, tail)
  end

  defp add_to_acc({:map, item}, acc_items) do
    quote(do: %{unquote(item) => unquote(acc_items)})
  end
  defp add_to_acc({:keyword, item}, acc_items) do
    quote(do: [{unquote(item), unquote(acc_items)}])
  end
  defp add_to_acc({:list, _}, acc_items) do
    quote(do: [unquote(acc_items)])
  end
  defp add_to_acc({:tuple, _}, acc_items) do
    quote(do: {unquote(acc_items)})
  end

  defp fallback_from_acc(path_items, acc) do
    Enum.flat_map(path_items, & gen_fallback(&1, acc))
  end

  defp gen_fallback({:map, key}, acc) do
    quote generated: true do
      %{} = other -> Map.put(other, unquote(key), unquote(acc))
    end
  end
  defp gen_fallback({:list, _}, acc) do
    quote generated: true do
      l when is_list(l) -> [unquote(acc) | l]
    end
  end
  defp gen_fallback({:tuple, _}, acc) do
    quote generated: true do
      t when is_tuple(t) -> Tuple.append(t, unquote(acc))
    end
  end
  defp gen_fallback({:keyword, key}, acc) do
    quote generated: true do
      kwd when is_list(kwd) ->
        [{unquote(key), unquote(acc)} | kwd]
    end
  end

end
