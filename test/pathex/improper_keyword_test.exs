defmodule Pathex.ImproperKeywordTest do
  use ExUnit.Case

  import Pathex

  describe "path/2" do
    test "Atom key" do
      improper = [{:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 1} = view(improper, path(:x))
      assert {:ok, 5} = view(improper, path(:z))
    end

    test "Atom key, list-like improper" do
      improper = [0, {:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 1} = view(improper, path(:x))
      assert {:ok, 5} = view(improper, path(:z))
    end

    test "Index key" do
      improper = [{:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 4} = view(improper, path(3))
      assert {:ok, {:y, 2}} = view(improper, path(1))

      improper = [0, {:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 4} = view(improper, path(4))
      assert {:ok, {:y, 2}} = view(improper, path(2))
    end

    test "Variable key" do
      improper = [{:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      x = :x
      three = 3
      assert {:ok, 1} = view(improper, path(x))
      assert {:ok, 4} = view(improper, path(three))

      improper = [0, {:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 1} = view(improper, path(x))
      assert {:ok, 3} = view(improper, path(three))
    end

    test "Variable key, annotated" do
      improper = [{:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      x = :x
      three = 3
      assert {:ok, 1} = view(improper, path(x :: :keyword))
      assert {:ok, 4} = view(improper, path(three :: :list))
      assert :error = view(improper, path(x :: :list))
      assert :error = view(improper, path(three :: :keyword))

      improper = [0, {:x, 1}, {:y, 2}, 3, 4, {:z, 5}]

      assert {:ok, 1} = view(improper, path(x :: :keyword))
      assert {:ok, 3} = view(improper, path(three :: :list))
      assert :error = view(improper, path(x :: :list))
      assert :error = view(improper, path(three :: :keyword))
    end
  end
end
