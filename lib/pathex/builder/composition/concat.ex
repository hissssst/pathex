defmodule Pathex.Builder.Composition.Concat do
  # Builder for paths concatenation (with `~>`)
  @moduledoc false

  @behaviour Pathex.Builder.Composition
  alias Pathex.Builder.Code
  alias Pathex.Builder.Composition

  @impl Pathex.Builder.Composition
  def build(paths) do
    [
      view: build_view(paths),
      update: build_update(paths),
      delete: build_delete(paths),
      inspect: Composition.build_inspect(paths, :~>),
      force_update: build_force_update(paths)
    ]
  end

  # Deleter

  defp build_delete([head | tail]) do
    structure = {:x, [], Elixir}
    func = {:func, [], Elixir}
    inner_arg = {:x, [], Elixir}

    inner = do_build_delete(tail, inner_arg, func)

    quote do
      unquote(head).(
        :delete,
        {unquote(structure),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
    |> Code.new([structure, func])
  end

  defp do_build_delete([item], arg, func) do
    quote do
      unquote(item).(:delete, {unquote(arg), unquote(func)})
    end
  end

  defp do_build_delete([head | tail], arg, func) do
    inner_arg = {:x, [], Elixir}
    inner = do_build_delete(tail, inner_arg, func)

    quote do
      unquote(head).(
        :delete,
        {unquote(arg),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
  end

  # Force update

  defp build_force_update([head | tail]) do
    structure = {:x, [], Elixir}
    func = {:func, [], Elixir}
    default = {:default, [], Elixir}

    {[head_default | defaults], withs} = generate_withs(tail, func, default)

    inner_arg = {:x, [], Elixir}
    inner = do_build_force_update(tail, defaults, inner_arg, func)

    quote do
      with unquote_splicing(withs) do
        unquote(head).(
          :force_update,
          {unquote(structure),
           fn unquote(inner_arg) ->
             unquote(inner)
           end, unquote(head_default)}
        )
      end
    end
    |> Code.new([structure, func, default])
  end

  defp generate_withs(items, func, default) do
    rets = generate_vars_with_prefix("default", length(items))
    defaults = [default | rets]
    items = Enum.reverse(items)

    withs =
      [items, rets, defaults]
      |> Enum.zip()
      |> Enum.map(fn {item, ret, default} ->
        to_with_item(item, ret, func, default)
      end)

    {Enum.reverse(defaults), withs}
  end

  defp generate_vars_with_prefix(prefix, l) do
    for i <- 1..l, do: {:"#{prefix}_#{i}", [], Elixir}
  end

  defp to_with_item(item, ret, func, value) do
    quote do
      {:ok, unquote(ret)} <-
        with(
          :error <- unquote(item).(:force_update, {%{}, unquote(func), unquote(value)}),
          :error <- unquote(item).(:force_update, {[], unquote(func), unquote(value)})
        ) do
          unquote(item).(:force_update, {{}, unquote(func), unquote(value)})
        end
    end
  end

  defp do_build_force_update([item], [default], arg, func) do
    quote do
      unquote(item).(:force_update, {unquote(arg), unquote(func), unquote(default)})
    end
  end

  defp do_build_force_update([head | item_tail], [default | default_tail], arg, func) do
    inner_arg = {:x, [], Elixir}
    inner = do_build_force_update(item_tail, default_tail, inner_arg, func)

    quote do
      unquote(head).(
        :force_update,
        {unquote(arg),
         fn unquote(inner_arg) ->
           unquote(inner)
         end, unquote(default)}
      )
    end
  end

  # Update

  defp build_update([head | tail]) do
    structure = {:x, [], Elixir}
    func = {:func, [], Elixir}
    inner_arg = {:x, [], Elixir}

    inner = do_build_update(tail, inner_arg, func)

    quote do
      unquote(head).(
        :update,
        {unquote(structure),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
    |> Code.new([structure, func])
  end

  defp do_build_update([item], arg, func) do
    quote do
      unquote(item).(:update, {unquote(arg), unquote(func)})
    end
  end

  defp do_build_update([head | tail], arg, func) do
    inner_arg = {:x, [], Elixir}
    inner = do_build_update(tail, inner_arg, func)

    quote do
      unquote(head).(
        :update,
        {unquote(arg),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
  end

  # View

  defp build_view([head | tail]) do
    structure = {:x, [], Elixir}
    func = {:func, [], Elixir}
    inner_arg = {:x, [], Elixir}
    inner = do_build_view(tail, inner_arg, func)

    quote do
      unquote(head).(
        :view,
        {unquote(structure),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
    |> Code.new([structure, func])
  end

  defp do_build_view([item], arg, func) do
    quote do
      unquote(item).(:view, {unquote(arg), unquote(func)})
    end
  end

  defp do_build_view([head | tail], arg, func) do
    inner_arg = {:x, [], Elixir}
    inner = do_build_view(tail, inner_arg, func)

    quote do
      unquote(head).(
        :view,
        {unquote(arg),
         fn unquote(inner_arg) ->
           unquote(inner)
         end}
      )
    end
  end
end
