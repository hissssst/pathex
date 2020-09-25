defmodule Pathex.Operations do

  @moduledoc """
  Module for working with modificators for paths
  Like :naive, :json, :map
  """

  alias Pathex.Builder
  alias Builder.{
    ForceUpdater, MatchableViewer,
    SimpleViewer, SimpleUpdater
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
    raise ArgumentError, "Modificator #{inspect mod} doesn't exist"
  end

end
