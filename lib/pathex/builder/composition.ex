defmodule Pathex.Builder.Composition do

  @moduledoc """
  Behaviour for building quoted composition-closures of
  multiple paths
  """

  @doc """
  Builds composition of path-closure specified as
  quoted variables in input list
  """
  @callback build([Macro.t()]) :: [{Pathex.Operations.name(), Pathex.Builder.Code.t()}]

end
