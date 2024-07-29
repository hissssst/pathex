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

  @spec filter_combination(Pathex.Combination.t(), Pathex.mod(), Pathex.Combination.t()) :: {:ok, Pathex.Combination.t()} | {:error, any()}
  def filter_combination(combination, mod, acc \\ [])
  def filter_combination([], _mod, acc), do: {:ok, Enum.reverse(acc)}
  def filter_combination([head | tail], mod, acc) do
    with {:ok, step} <- filter_one(mod, head) do
      filter_combination(tail, mod, [step | acc])
    end
  end

  defp filter_one(:naive, [_ | _] = path), do: {:ok, path}
  defp filter_one(:map, path) do
    case Keyword.fetch(path, :map) do
      :error -> {:error, "At least some map key expected, but got only #{inspect(path)}"}
      {:ok, map_key} -> {:ok, map: map_key}
    end
  end
  defp filter_one(:json, path) do
    filtered =
      Enum.filter(path, fn
        {:map, i} when is_integer(i) -> false
        {:map, _} -> true
        {:list, i} when is_integer(i) and i >= 0 -> true
        _ -> false
      end)

    case filtered do
      [] ->
        [{_, value} | _] = path
        types = Enum.map_join(path, ", ", fn {type, _} -> type end)
        reason = ":json modifier expects any non-integer map key or positive list index literal. " <>
          "But got #{value} for #{types}"

        {:error, reason}

      filtered ->
        {:ok, filtered}
    end
  end
end
