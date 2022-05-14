defmodule AnnotatedPathTest do
  use ExUnit.Case

  import Pathex

  describe "By type" do
    test ":tuple" do
      p = path(1 :: :tuple)
      assert {:ok, 2} = view({1, 2}, p)
      assert {:ok, 2} = view({1, 2, 3, 4}, p)
      assert :error = view({1}, p)
      assert :error = view([1, 2], p)
      assert :error = view(%{1 => 2}, p)
    end

    test ":list" do
      p = path(1 :: :list)
      assert {:ok, 2} = view([1, 2], p)
      assert {:ok, 2} = view([1, 2, 3, 4], p)
      assert :error = view([1], p)
      assert :error = view({1, 2}, p)
      assert :error = view(%{1 => 2}, p)
    end

    test ":keyword" do
      p = path(:x :: :keyword)

      assert {:ok, 1} = view([x: 1], p)
      assert {:ok, 1} = view([a: 0, x: 1], p)
      assert {:ok, 1} = view([a: 0, x: 1, y: 2], p)
      assert {:ok, 1} = view([a: 0, x: 1, x: 2], p)
      assert :error = view(%{x: 1}, p)
      assert :error = view([:x, 1], p)
    end

    test ":map" do
      p = path(:x :: :map)

      assert {:ok, 1} = view(%{x: 1}, p)
      assert {:ok, 1} = view(%{a: 0, x: 1}, p)
      assert {:ok, 1} = view(%{a: 0, x: 1, y: 2}, p)
      assert :error = view([x: 1], p)
      assert :error = view({:x, 1}, p)
    end
  end

  describe "Composed" do
    test "all" do
      p = path(
        (:x :: :map) /
        (:y :: :keyword) /
        (0 :: :tuple) /
        (0 :: :list)
      )

      assert {:ok, 1} = view %{x: [y: {[1]}]}, p
      assert :error = view [x: [y: {[1]}]], p
      assert :error = view %{x: %{y: {[1]}}}, p
      assert :error = view %{x: [y: [[1]]]}, p
      assert :error = view %{x: [y: {{1}}]}, p
    end
  end
end
