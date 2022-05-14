defmodule Pathex.Operations do
  # Module for working with modifiers for paths
  # Like :naive, :json, :map
  @moduledoc false

  alias Pathex.Builder

  alias Builder.{
    ForceUpdater,
    Inspector,
    MatchableUpdater,
    MatchableViewer,
    SimpleDeleter,
    SimpleUpdater,
    SimpleViewer
  }

  @type name :: :view | :force_update | :update | :delete | :inspect
  @type t :: %{name() => Builder.t()}

  @doc """
  This function finds the best suitable builders for combination
  """
  @spec builders_for_combination(Pathex.Combination.t()) :: t()
  def builders_for_combination(combination) do
    cond do
      map_compatible?(combination) ->
        suggest(:map)

      json_compatible?(combination) ->
        suggest(:json)

      true ->
        suggest(:naive)
    end
  end

  @spec map_compatible?(Pathex.Combination.t()) :: boolean()
  defp map_compatible?(combination) do
    Enum.all?(combination, fn path ->
      Enum.all?(path, &match?({:map, _}, &1))
    end)
  end

  @spec json_compatible?(Pathex.Combination.t()) :: boolean()
  defp json_compatible?(combination) do
    Enum.all?(combination, fn path ->
      Enum.all?(path, fn
        {:list, i} when is_integer(i) and i >= 0 ->
          true

        {:map, _} ->
          true

        _ ->
          false
      end)
    end)
  end

  @spec suggest(Pathex.mod()) :: t()
  defp suggest(:naive) do
    %{
      delete: SimpleDeleter,
      force_update: ForceUpdater,
      update: SimpleUpdater,
      inspect: Inspector,
      view: SimpleViewer
    }
  end

  defp suggest(mod) when mod in ~w[json map]a do
    %{
      delete: SimpleDeleter,
      force_update: ForceUpdater,
      update: MatchableUpdater,
      inspect: Inspector,
      view: MatchableViewer
    }
  end

  defp suggest(mod) when is_atom(mod) do
    raise ArgumentError, "Modificator #{mod} is not supported"
  end

  @spec filter_combination(Pathex.Combination.t(), Pathex.mod()) :: Pathex.Combination.t()
  def filter_combination(combination, mod) do
    Enum.map(combination, &filter_one(mod, &1))
  end

  defp filter_one(:naive, path), do: path
  defp filter_one(:map, path), do: Keyword.take(path, [:map])

  defp filter_one(:json, path) do
    Enum.filter(path, fn
      {:map, i} when is_integer(i) -> false
      {:map, _} -> true
      {:list, i} when is_integer(i) and i >= 0 -> true
      _ -> false
    end)
  end
end
