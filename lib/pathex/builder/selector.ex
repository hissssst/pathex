defmodule Pathex.Builder.Selector do

  import Pathex.Builder, only: [list_match: 2, pin: 1]
  @callback build(Pathex.Combination.t()) :: Pathex.Builder.Code.t()

  def is_matchable?({type, _}) when type in [:map, :list], do: true
  def is_matchable?(_), do: false

  def match_from_path(path, initial \\ {:x, [], Elixir}) do
    path
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, initial}, fn
      {:map, key}, {:ok, acc} ->
        {:cont, {:ok, quote(do: %{unquote(key) => unquote(acc)})}}

      {:list, index}, {:ok, acc} ->
        {:cont, {:ok, list_match(index, acc)}}

      item, _ ->
        {:halt, {:error, {:bad_item, item}}}
    end)
  end

  def create_getter({:tuple, index}, tail) do
    quote do
      t when is_tuple(t) and tuple_size(t) > unquote(index) ->
        elem(t, unquote(index)) |> unquote(tail)
    end
  end
  def create_getter({:keyword, key}, tail) do
    quote do
      [{_, _} | _] = kwd ->
        with {:ok, value} <- Keyword.fetch(kwd, unquote(key)) do
          value |> unquote(tail)
        end
    end
  end
  def create_getter({:map, key}, tail) do
    key = pin(key)
    quote do
      %{unquote(key) => x} -> x |> unquote(tail)
    end
  end
  def create_getter({:list, index}, tail) do
    x = {:x, [], Elixir}
    match = list_match(index, x)
    quote do
      unquote(match) -> unquote(x) |> unquote(tail)
    end
  end

  def fallback() do
    quote do
      _ -> :error
    end
  end

end
