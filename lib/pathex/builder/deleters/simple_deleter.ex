defmodule Pathex.Builder.SimpleDeleter do

  alias Pathex.Common
  alias Pathex.Builder.Viewer
  @behaviour Pathex.Builder

  @structure_variable {:x, [], Elixir}
  @function_variable {:function, [], Elixir}

  def build(combination) do
    {last, combination} = List.pop_at(combination, -1)

    deleters = Enum.flat_map(last, &create_deleter/1)
    last_case = Common.to_case(deleters ++ Viewer.fallback())

    combination
    |> Enum.reverse()
    |> Enum.reduce(last_case, &reduce_into/2)
    |> Macro.prewalk(&Viewer.expand_local/1) # Workaround for bad expansion of `and` in `when`
    |> Pathex.Builder.Code.new_arg_pipe([@structure_variable, @function_variable])
  end

  defp reduce_into(path_items, acc) do
    path_items
    |> Enum.flat_map(& Viewer.create_getter(&1, acc))
    |> Kernel.++(Viewer.fallback())
    |> Common.to_case()
  end

  # Non variable cases
  def create_deleter({:tuple, index}) when is_integer(index) and index >= 0 do
    quote do
      t when is_tuple(t) and (tuple_size(t) > unquote(index)) ->
        unquote(@function_variable).(Tuple.delete_at(t, unquote(index)))
    end
  end
  def create_deleter({:keyword, key}) when is_atom(key) do
    quote do
      [{a, _} | _] = kwd when is_atom(a) ->
        case Keyword.has_key?(kwd, unquote(key)) do
          true ->
            unquote(@function_variable).(Keyword.delete(kwd, unquote(key)))
          false ->
            :error
        end
    end
  end
  def create_deleter({:map, key}) do
    pinned = Common.pin(key)
    quote do
      %{unquote(pinned) => x} = map ->
        unquote(@function_variable).(Map.delete(map, unquote(key)))
    end
  end
  def create_deleter({:list, index}) when is_integer(index) and index >= 0 do
    x = {:_, [], Elixir}
    match = Common.list_match(index, x)
    quote do
      unquote(match) = list ->
        unquote(@function_variable).(List.delete_at(list, unquote(index)))
    end
  end

  # Variable cases
  def create_deleter({:keyword, {_, _, _} = key}) do
    quote do
      [{a, _} | _] = kwd when is_atom(a) ->
        case Keyword.has_key?(kwd, unquote(key)) do
          true ->
            unquote(@function_variable).(Keyword.delete(kwd, unquote(key)))
          false ->
            :error
        end
    end
  end
  def create_deleter({:list, {_, _, _} = index}) do
    quote do
      l when is_list(l) and is_integer(unquote(index)) ->
        case List.pop_at(l, index, :__pathex_var_not_found__) do
          {:__pathex_var_not_found__, _} ->
            :error
          {_, l} ->
            unquote(@function_variable).(l)
        end
    end
  end
  def create_deleter({:tuple, {_, _, _} = index}) do
    quote do
      t when is_tuple(t) and is_integer(index) ->
        if tuple_size(t) > unquote(index) do
          unquote(@function_variable).(Tuple.delete_at(t, unquote(index)))
        else
          :error
        end
    end
  end

end
