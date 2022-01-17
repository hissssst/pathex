defmodule Pathex.DeletionTest do
  use ExUnit.Case
  use Pathex

  defmacrop delete(s, p) do
    quote do
      Pathex.delete(unquote(s), unquote(p))
    end
  end

  test "simple paths delete stuff" do
    assert {:ok, %{}} == delete(%{x: 1}, path(:x))
    assert {:ok, []} == delete([x: 1], path(:x))

    assert {:ok, %{y: 2}} == delete(%{x: 1, y: 2}, path(:x))
    assert {:ok, [y: 2]} == delete([x: 1, y: 2], path(:x))

    assert {:ok, {}} == delete({1}, path(0))
    assert {:ok, []} == delete([1], path(0))

    assert {:ok, {2}} == delete({1, 2}, path(0))
    assert {:ok, [2]} == delete([1, 2], path(0))

    assert {:ok, %{3 => 4}} == delete(%{1 => 2, 3 => 4}, path(1))

    assert {:ok, %{x: 1, y: %{}}} == delete(%{x: 1, y: %{z: 2}}, path(:y / :z))
    assert {:ok, %{x: 1, y: []}} == delete(%{x: 1, y: [z: 2]}, path(:y / :z))

    assert {:ok, [x: 1, y: []]} == delete([x: 1, y: [z: 2]], path(:y / :z))
    assert {:ok, [x: 1, y: %{}]} == delete([x: 1, y: %{z: 2}], path(:y / :z))

    # Errors

    assert :error == delete({1}, path(:x))
    assert :error == delete([1], path(:x))

    assert :error == delete(%{y: 2}, path(:x))
    assert :error == delete([y: 2], path(:x))

    assert :error == delete({}, path(0))
    assert :error == delete([], path(0))

    assert :error == delete(%{x: %{z: 2}}, path(:y / :z))
    assert :error == delete(%{x: [z: 2]}, path(:y / :z))

    assert :error == delete([x: [z: 2]], path(:y / :z))
    assert :error == delete([x: %{z: 2}], path(:y / :z))
  end

  test "Compostition works as intended" do
    assert {:ok, %{x: %{}}} == delete(%{x: %{y: 1}}, path(:x) ~> path(:y))
    assert {:ok, [x: %{}]} == delete([x: %{y: 1}], path(:x) ~> path(:y))
    assert {:ok, %{x: []}} == delete(%{x: [y: 1]}, path(:x) ~> path(:y))

    assert {:ok, %{x: %{x: 2}, y: 3}} ==
             delete(%{x: %{y: %{x: 1}, x: 2}, y: 3}, path(:x) ~> path(:y))

    assert :error = delete(%{x: 1}, path(:x) ~> path(:y))
    assert :error = delete(%{x: %{x: 1}}, path(:x) ~> path(:y))
    assert :error = delete(%{x: [x: 1]}, path(:x) ~> path(:y))
    assert :error = delete(%{y: %{x: 1}}, path(:x) ~> path(:y))
  end

  test "recur deletion works as intended" do
    import Pathex.Lenses.Recur
    assert {:ok, %{x: %{x: %{x: %{}}}}} = delete(%{x: %{x: %{x: %{x: 1}}}}, recur(path(:x)))
  end
end
