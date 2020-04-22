defmodule Pathex.Builder do

  def build(combination, mod) when mod in ['map', 'json'] do
    __MODULE__.MatchableSelector.build(combination)
  end
  def build(combination, 'naive') do
    __MODULE__.OptimizedSelector.build(combination)
  end

end
