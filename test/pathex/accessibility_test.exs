defmodule Pathex.AccessibilityTest do

  use ExUnit.Case

  doctest Pathex.Accessibility, import: true

  import Pathex
  import Pathex.Accessibility

  describe "from_list/2" do
    test "just works" do
      p = from_list(~w[x y z]a)

      assert {:ok, 1} = view(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, 1} = view(%{x: %{y: [z: 1]}}, p)
      assert {:ok, 1} = view([x: %{y: %{z: 1}}], p)

      assert :error = view(%{z: %{y: %{x: 1}}}, p)
      assert :error = view(%{x: %{y: [x: 1]}}, p)
      assert :error = view([x: %{y: %{}}], p)
    end

    test "map mod" do
      p = from_list([:x, :y, 1], :map)

      assert {:ok, 2} = view(%{x: %{y: %{1 => 2}}}, p)
      assert :error = view(%{x: %{y: [0, 2]}}, p)
      assert :error = view([x: %{y: %{1 => 2}}], p)
    end
  end

  describe "from_access/1" do
    test "view" do
      p = from_access(~w[x y z]a)

      assert {:ok, 1} = view(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, 1} = view(%{x: %{y: [z: 1]}}, p)
      assert {:ok, 1} = view([x: %{y: %{z: 1}}], p)

      assert :error = view(%{z: %{y: %{x: 1}}}, p)
      assert :error = view(%{x: %{y: [x: 1]}}, p)
      assert :error = view([x: %{y: %{}}], p)
    end

    test "update" do
      p = from_access(~w[x y z]a)

      assert {:ok, %{x: %{y: %{z: 2}}}} = set(%{x: %{y: %{z: 1}}}, p, 2)
      assert {:ok, %{x: %{y: [z: 2]}}}  = set(%{x: %{y: [z: 1]}}, p, 2)
      assert {:ok, [x: %{y: %{z: 2}}]}  = set([x: %{y: %{z: 1}}], p, 2)

      assert :error = set(%{z: %{y: %{x: 1}}}, p, 2)
      assert :error = set(%{x: %{y: [x: 1]}}, p, 2)
      assert :error = set([x: %{y: %{}}], p, 2)
    end

    test "delete" do
      p = from_access(~w[x y z]a)

      assert {:ok, %{x: %{y: %{}}}} = delete(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, %{x: %{y: []}}} = delete(%{x: %{y: [z: 1]}}, p)
      assert {:ok, [x: %{y: %{}}]} = delete([x: %{y: %{z: 1}}], p)

      assert :error = delete(%{z: %{y: %{x: 1}}}, p)
      assert :error = delete(%{x: %{y: [x: 1]}}, p)
      assert :error = delete([x: %{y: %{}}], p)
    end

    test "inspect" do
      assert "accessible([:x, :y, :z])" == Pathex.inspect from_access ~w[x y z]a
    end
  end

  describe "to_access/1" do
    test "get" do
      a = to_access path :x / :y / :z

      assert 1   == get_in(%{x: %{y: %{z: 1}}}, a)
      assert nil == get_in(%{x: %{y: %{}}}, a)
      assert nil == get_in(%{x: %{}}, a)
      assert nil == get_in(%{}, a)
    end

    test "pop" do
      a = to_access path :x / :y / :z

      assert {1,   %{x: %{y: %{}}}} == pop_in(%{x: %{y: %{z: 1}}}, a)
      assert {nil, %{x: %{y: %{}}}} == pop_in(%{x: %{y: %{}}}, a)
      assert {nil, %{x: %{}}}       == pop_in(%{x: %{}}, a)
      assert {nil, %{}}             == pop_in(%{}, a)
    end

    test "update" do
      a = to_access path :x / :y / :z
      f = & &1 + 1

      assert %{x: %{y: %{z: 2}}} == update_in(%{x: %{y: %{z: 1}}}, a, f)
      assert %{x: %{y: %{}}}     == update_in(%{x: %{y: %{}}}, a, f)
      assert %{x: %{}}           == update_in(%{x: %{}}, a, f)
      assert %{}                 == update_in(%{}, a, f)
    end
  end

end
