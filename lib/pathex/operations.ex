defmodule Pathex.Operations do

  @moduledoc """
  Module for working with modifiers for paths
  Like :naive, :json, :map
  """

  alias Pathex.Builder
  alias Builder.{
    ForceUpdater, MatchableViewer,
    SimpleUpdater, SimpleViewer
  }

  @type name :: :view | :force_update | :update
  @type t :: %{name() => Builder.t()}

  @spec from_mod(Pathex.mod()) :: t()
  def from_mod(:naive) do
    %{
      view:         SimpleViewer,
      force_update: ForceUpdater,
      update:       SimpleUpdater
    }
  end
  def from_mod(mod) when mod in ~w[json map]a do
    %{
      view:         MatchableViewer,
      force_update: ForceUpdater,
      update:       SimpleUpdater
    }
  end
  def from_mod(mod) when is_atom(mod) do
    raise ArgumentError, "Modificator #{mod} is not supported"
  end

  def filter_combination(combination, mod) do
    Enum.map(combination, & filter_one(mod, &1))
  end

  defp filter_one(:naive, c), do: c
  defp filter_one(:map, c), do: Keyword.take(c, [:map])
  defp filter_one(:json, c), do: Keyword.take(c, [:map, :list])

end
