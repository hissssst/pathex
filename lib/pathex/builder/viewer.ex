defmodule Pathex.Builder.Viewer do
  # Module with common functions for viewers
  @moduledoc false

  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  # Helpers

  def match_from_path(path, initial \\ {:x, [], Elixir}) do
    path
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, initial}, fn
      {:map, key}, {:ok, acc} ->
        {:cont, {:ok, quote(do: %{unquote(pin(key)) => unquote(acc)})}}

      {:list, index}, {:ok, acc} ->
        {:cont, {:ok, list_match(index, acc)}}

      item, _ ->
        {:halt, {:error, {:bad_item, item}}}
    end)
  end

  # Non variable cases
  def create_getter({:tuple, index}, tail) when is_integer(index) and index >= 0 do
    quote do
      tuple when is_tuple(tuple) and tuple_size(tuple) > unquote(index) ->
        elem(tuple, unquote(index)) |> unquote(tail)
    end
  end

  def create_getter({:tuple, index}, _tail) when is_integer(index) and index < 0 do
    # Can't create getter for tuple with negative index. What can we do?
    raise ArgumentError, "Tuple index can't be negative"
  end

  def create_getter({:keyword, key}, tail) when is_atom(key) do
    quote do
      kwd when is_list(kwd) ->
        with {:ok, value} <- Keyword.fetch(kwd, unquote(key)) do
          value |> unquote(tail)
        end
    end
  end

  def create_getter({:map, key}, tail) do
    quote do
      %{unquote(pin(key)) => x} -> x |> unquote(tail)
    end
  end

  def create_getter({:list, index}, tail) when is_integer(index) and index >= 0 do
    x = {:x, [], Elixir}
    match = list_match(index, x)

    quote do
      unquote(match) -> unquote(x) |> unquote(tail)
    end
  end

  def create_getter({:list, index}, tail) when is_integer(index) and index < 0 do
    quote do
      list when is_list(list) ->
        case Enum.at(list, unquote(index), :__pathex_var_not_found__) do
          :__pathex_var_not_found__ ->
            :error

          value ->
            value |> unquote(tail)
        end
    end
  end

  # Variable cases
  def create_getter({:keyword, key}, tail) when is_var(key) do
    quote do
      kwd when is_list(kwd) and is_atom(unquote(key)) ->
        with {:ok, value} <- Keyword.fetch(kwd, unquote(key)) do
          value |> unquote(tail)
        end
    end
  end

  def create_getter({:list, index}, tail) when is_var(index) do
    quote do
      list when is_list(list) and is_integer(unquote(index)) ->
        case Enum.at(list, unquote(index), :__pathex_var_not_found__) do
          :__pathex_var_not_found__ ->
            :error

          value ->
            value |> unquote(tail)
        end
    end
  end

  def create_getter({:tuple, index}, tail) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) > unquote(index) ->
        elem(tuple, unquote(index)) |> unquote(tail)
    end
  end

  def fallback do
    quote do
      _ -> :error
    end
  end

  # Some bug in Macro.expand
  def expand_local({:and, _, _} = quoted), do: quoted

  def expand_local(quoted) do
    env = %Macro.Env{requires: [__MODULE__]}
    Macro.expand(quoted, env)
  end
end
