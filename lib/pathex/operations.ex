defmodule Pathex.Operations do

  @moduledoc """
  Module for working with modificators for paths
  Like :naive, :json, :map
  """

  alias Pathex.Builder
  alias Builder.{
    ForceSetter, MatchableSelector,
    SimpleSelector, SimpleSetter, UpdateSetter
  }

  @type name :: :get | :set | :force_set | :update
  @type t :: %{name() => Builder.t()}

  @spec from_mod(Pathex.mod()) :: t()
  def from_mod(:naive) do
    %{
      get:       SimpleSelector,
      set:       SimpleSetter,
      force_set: ForceSetter,
      update:    UpdateSetter
    }
  end
  def from_mod(mod) when mod in ~w[json map]a do
    %{
      get:       MatchableSelector,
      set:       SimpleSetter,
      force_set: ForceSetter,
      update:    UpdateSetter
    }
  end
  def from_mod(mod) when is_atom(mod) do
    raise ArgumentError, "Modificator #{inspect mod} doesn't exist"
  end

end
