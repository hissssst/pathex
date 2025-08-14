defmodule Pathex.DeletionTest do
  use ExUnit.Case
  import Pathex

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

  describe "Composition" do
    test "concat" do
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

    test "and" do
      assert {:ok, %{x: %{}, y: %{}}} ==
               delete(%{x: %{y: 1}, y: %{x: 2}}, path(:x / :y) &&& path(:y / :x))
    end
  end

  describe "Delete me" do
    import Pathex.Lenses

    test "star ~> matching" do
      data =
        1..1000
        |> Enum.shuffle()

      assert {:ok, list} = Pathex.delete(data, star() ~> matching(x when x > 500))
      assert length(list) == 500
    end

    test "star ~> matching exact" do
      assert {:ok, %{x: [1, 2]}} == Pathex.delete(%{x: [1, 2, 3]}, path(:x) ~> star() ~> matching(x when x >= 3))

      assert :error == Pathex.delete([1, 2, 3], star() ~> matching(x when x >= 4))
      assert :error == Pathex.delete(%{x: [1, 2, 3]}, path(:x) ~> star() ~> matching(x when x >= 4))
    end
  end

  describe "Regression" do
    import Pathex.Lenses

    test "some deletion" do
      assert {:ok, [2, 3]} == Pathex.delete([1, 2, 3], some())
      assert {:ok, %{x: [2, 3]}} == Pathex.delete(%{x: [1, 2, 3]}, path(:x) ~> some())
      assert {:ok, %{x: [1, 2]}} == Pathex.delete(%{x: [1, 2, 3]}, path(:x) ~> some() ~> matching(x when x >= 3))

      assert :error == Pathex.delete([1, 2, 3], some() ~> matching(x when x >= 4))
      assert :error == Pathex.delete(%{x: [1, 2, 3]}, path(:x) ~> some() ~> matching(x when x >= 4))
    end
  end

  describe "without" do
    import Pathex.Lenses

    test "just works" do
      assert [2, 3] == Pathex.without([1, 2, 3], some())
      assert %{x: [2, 3]} == Pathex.without(%{x: [1, 2, 3]}, path(:x) ~> some())
      assert %{x: [1, 2]} == Pathex.without(%{x: [1, 2, 3]}, path(:x) ~> some() ~> matching(x when x >= 3))

      assert [1, 2, 3] == Pathex.without([1, 2, 3], some() ~> matching(x when x >= 4))
      assert %{x: [1, 2, 3]} == Pathex.without(%{x: [1, 2, 3]}, path(:x) ~> some() ~> matching(x when x >= 4))
    end
  end
end
