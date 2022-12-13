defmodule Pathex.Combination do
  # Module for combination structures
  @moduledoc false

  @type variable :: {atom(), list(), atom()}
  @type struct_type :: :map | :keyword | :list | :tuple
  @type pair ::
          {:map, any()}
          | {:keyword, atom() | variable()}
          | {:list, integer() | variable()}
          | {:tuple, non_neg_integer() | variable()}

  @typedoc """
  Plain representation of one path for generating one `case(do:)`
  or one matchable case
  """
  @type path :: [pair()]

  @typedoc """
  Representation of one path combination

  For example, viewer for this combination:
  ```elixir
  [
    [map: :x, keyword: :x]
    [map: :y]
  ]
  ```

  Will look like
  ```elixir
  case do
    %{x: inner} ->
      case inner do
        %{y: value} -> {:ok, value}
        _ -> :error
      end

    [_ | _] = keyword->
      case Keyword.fetch(keyword, :x) do
        {:ok, inner} ->
          case inner do
            %{y: value} -> {:ok, value}
            _ -> :error
          end
        _ ->
          :error
      end

    _ ->
      :error
  end
  ```
  """
  @type t :: [[{struct_type(), Macro.t()}]]

  @doc """
  Simply transforms passed path into combination
  """
  @spec from_path(path()) :: t()
  def from_path(path) do
    Enum.map(path, &[&1])
  end

  @doc """
  Transforms combination into list of paths
  this combination defines
  """
  @spec to_paths(t()) :: [path()]
  def to_paths([]), do: []
  def to_paths([last]), do: Enum.map(last, &List.wrap/1)

  def to_paths([heads | tail]) do
    Enum.flat_map(heads, fn head ->
      tail
      |> to_paths()
      |> Enum.map(&[head | &1])
    end)
  end

  @doc """
  Counts total size of clauses created from this composition
  """
  @spec size(t()) :: non_neg_integer()
  def size(combination) do
    Enum.reduce(combination, 1, &(length(&1) * &2))
  end
end
