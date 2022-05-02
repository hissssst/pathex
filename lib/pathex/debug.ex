defmodule Pathex.Debug do
  @moduledoc """
  Special lens which logs all operation
  and performs the same way `matching(_)` does
  """

  def debug(prefix \\ {:_, [], nil}) do
    fn
      :inspect, _ ->
        {:debug, [], [prefix]}

      :delete, {input} ->
        IO.puts "#{prefix} Called delete on #{inspect input, pretty: true}"
        :error

      :force_update, {input, fun, _default} ->
        IO.puts "#{prefix} Called force_update on #{inspect input, pretty: true}"
        fun.(input)

      op, {input, fun} ->
        IO.puts "#{prefix} Called #{op} on #{inspect input, pretty: true}"
        fun.(input)
    end
  end

end
