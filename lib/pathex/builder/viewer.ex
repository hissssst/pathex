defmodule Pathex.Builder.Viewer do
  # Module with common functions for viewers
  @moduledoc false

  alias Pathex.Combination
  import Pathex.Common, only: [list_match: 2, pin: 1, is_var: 1]

  # Helpers

  @spec match_from_path(Pathex.Combination.path(), Macro.t()) ::
          {:ok, Macro.t()} | {:error, {:bad_item, any()}}
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
  @spec create_viewer(Combination.pair(), Macro.t()) :: Macro.t()
  def create_viewer({:tuple, index}, tail) when is_integer(index) and index >= 0 do
    quote do
      tuple when is_tuple(tuple) and tuple_size(tuple) > unquote(index) ->
        :erlang.element(unquote(index + 1), tuple) |> unquote(tail)
    end
  end

  def create_viewer({:tuple, index}, tail) when is_integer(index) and index < 0 do
    quote do
      tuple when is_tuple(tuple) and tuple_size(tuple) >= unquote(-index) ->
        index = tuple_size(tuple) + unquote(index + 1)
        :erlang.element(index, tuple) |> unquote(tail)
    end

    # # Can't create getter for tuple with negative index. What can we do?
    # raise ArgumentError, "Tuple index can't be negative"
  end

  def create_viewer({:keyword, key}, tail) when is_atom(key) do
    quote do
      kwd when is_list(kwd) ->
        with {:ok, value} <- Keyword.fetch(kwd, unquote(key)) do
          value |> unquote(tail)
        end
    end
  end

  def create_viewer({:map, key}, tail) do
    quote do
      %{unquote(pin(key)) => x} -> x |> unquote(tail)
    end
  end

  def create_viewer({:list, index}, tail) when is_integer(index) and index >= 0 do
    x = {:x, [], Elixir}
    match = list_match(index, x)

    quote do
      unquote(match) -> unquote(x) |> unquote(tail)
    end
  end

  def create_viewer({:list, index}, tail) when is_integer(index) and index < 0 do
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
  def create_viewer({:keyword, key}, tail) when is_var(key) do
    quote do
      kwd when is_list(kwd) and is_atom(unquote(key)) ->
        with {:ok, value} <- Keyword.fetch(kwd, unquote(key)) do
          value |> unquote(tail)
        end
    end
  end

  def create_viewer({:list, index}, tail) when is_var(index) do
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

  def create_viewer({:tuple, index}, tail) when is_var(index) do
    quote do
      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) >= 0 and
             tuple_size(tuple) > unquote(index) ->
        elem(tuple, unquote(index)) |> unquote(tail)

      tuple
      when is_tuple(tuple) and is_integer(unquote(index)) and
             unquote(index) < 0 and
             tuple_size(tuple) >= -unquote(index) ->
        index = tuple_size(tuple) + unquote(index) + 1
        :erlang.element(index, tuple) |> unquote(tail)
    end
  end

  @spec fallback() :: Macro.t()
  def fallback do
    quote do
      _ -> :error
    end
  end

  # Some bug in Macro.expand
  @spec expand_local(Macro.t()) :: Macro.t()
  def expand_local({:and, _, _} = quoted), do: quoted

  def expand_local(quoted) do
    env = %Macro.Env{requires: [__MODULE__]}
    Macro.expand(quoted, env)
  end
end
