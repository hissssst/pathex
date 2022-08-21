defmodule Pathex.Builder.Composition.Alongside do
  @moduledoc false
  # Builder for `Pathex.alongside/1` macro

  @behaviour Pathex.Builder.Composition
  alias Pathex.Builder.Code

  @impl Pathex.Builder.Composition
  def build(items) do
    [
      delete: build_delete(items),
      force_update: build_force_update(items),
      update: build_update(items),
      inspect: build_inspect(items),
      view: build_view(items)
    ]
  end

  # quote generated: true, bind_quoted: [list: list] do

  defp build_delete(list) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}

    quote do
      Enum.reduce_while(unquote(list), {:ok, unquote(input)}, fn path, {_, res} ->
        case path.(:delete, {res, unquote(func)}) do
          {:ok, res} -> {:cont, {:ok, res}}
          :error -> {:halt, :error}
        end
      end)
    end
    |> Code.new([input, func])
  end

  defp build_inspect(list) do
    list = Enum.map(list, &quote(do: unquote(&1).(:inspect, [])))

    # Manually escaping the alongside
    {:{}, [], [:alongside, [], [list]]}
    |> Code.new([])
  end

  defp build_view([left, right]) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}

    quote do
      with(
        {:ok, left_result} <- unquote(left).(:view, {unquote(input), unquote(func)}),
        {:ok, right_result} <- unquote(right).(:view, {unquote(input), unquote(func)})
      ) do
        {:ok, [left_result, right_result]}
      end
    end
    |> Code.new([input, func])
  end

  defp build_view(list) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}

    quote do
      unquote(list)
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, []}, fn path, {_, res} ->
        case path.(:view, {unquote(input), unquote(func)}) do
          {:ok, v} -> {:cont, {:ok, [v | res]}}
          :error -> {:halt, :error}
        end
      end)
    end
    |> Code.new([input, func])
  end

  defp build_update([left, right]) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}

    quote do
      with {:ok, res} <- unquote(left).(:update, {unquote(input), unquote(func)}) do
        unquote(right).(:update, {res, unquote(func)})
      end
    end
    |> Code.new([input, func])
  end

  defp build_update(list) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}

    quote do
      Enum.reduce_while(unquote(list), {:ok, unquote(input)}, fn path, {_, res} ->
        case path.(:update, {res, unquote(func)}) do
          {:ok, res} -> {:cont, {:ok, res}}
          :error -> {:halt, :error}
        end
      end)
    end
    |> Code.new([input, func])
  end

  defp build_force_update(list) do
    input = {:input_struct, [], nil}
    func = {:func, [], nil}
    default = {:default, [], nil}

    quote do
      Enum.reduce_while(unquote(list), {:ok, unquote(input)}, fn path, {_, res} ->
        case path.(:force_update, {res, unquote(func), unquote(default)}) do
          {:ok, res} -> {:cont, {:ok, res}}
          :error -> {:halt, :error}
        end
      end)
    end
    |> Code.new([input, func, default])
  end
end
