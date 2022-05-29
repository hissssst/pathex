defmodule Pathex.Debug do
  @moduledoc """
  Special lens which logs all operation
  and performs the same way `matching(_)` does
  """

  def debug(prefix \\ "") do
    spaced =
      if (prefix == "" or String.ends_with?(prefix, " ")) do
        prefix
      else
        prefix <> " "
      end

    fn
      :inspect, _ ->
        {:debug, [], [prefix]}

      :delete, {input} ->
        IO.puts("#{spaced}Called delete on #{inspect(input, pretty: true)}")
        :error

      :force_update, {input, fun, _default} ->
        IO.puts("#{spaced}Called force_update on #{inspect(input, pretty: true)}")
        fun.(input)

      op, {input, fun} ->
        IO.puts("#{spaced}Called #{op} on #{inspect(input, pretty: true)}")
        fun.(input)
    end
  end
end
