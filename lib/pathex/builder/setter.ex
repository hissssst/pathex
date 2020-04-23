defmodule Pathex.Builder.Setter do

  import Pathex.Builder, only: [list_match: 2, pin: 1]

  @callback build(Pathex.Combination.t()) :: Pathex.Builder.Code.t()

  def create_setter({:map, key}, tail) do
    pinned = pin(key)
    quote do
      %{unquote(pinned) => value} = map ->
        %{map | unquote(key) => value |> unquote(tail)}
    end
  end
  def create_setter({:list, index}, tail) do
    x = {:x, [], Elixir}
    match = list_match(index, x)
    quote do
      unquote(match) = list ->
        List.replace_at(list, unquote(index), unquote(x) |> unquote(tail))
    end
  end
  def create_setter({:tuple, index}, tail) do
    quote do
      t when is_tuple(t) ->
        val =
          elem(t, unquote(index))
          |> unquote(tail)
        put_elem(t, unquote(index), val)
    end
  end
  def create_setter({:keyword, key}, tail) do
    quote do
      [{_, _} | _] = keyword ->
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
