defmodule Pathex.LensesTest do
  use ExUnit.Case

  alias Pathex.Lenses
  require Lenses
  doctest Lenses

  require Pathex
  import Pathex

  test "Tricky alls" do
    px = path(:x)
    all = Lenses.all()

    inc = fn x -> x + 1 end

    # View
    assert {:ok, [1, 2]} = view(%{x: [1, 2]}, px ~> all)
    assert {:ok, [1, 2]} = at(%{x: [[x: 0], %{x: 1}]}, px ~> all ~> px, inc)

    assert :error = view(%{x: [%{x: 1}, %{y: 2}]}, px ~> all ~> px)

    # Update
    assert {:ok, [[x: 2], [x: 3]]} = over([[x: 1], [x: 2]], all ~> px, inc)
    assert {:ok, [[x: 2], %{x: 2}]} = set([[x: 1], %{x: 1}], all ~> px, 2)

    assert :error = set(%{x: [[x: 1], [y: 1]]}, px ~> all ~> px, 1)

    # Force
    assert {:ok, [x: 2, y: 2]} = force_set([x: 1, y: 1], all, 2)
    assert {:ok, [x: %{x: 2}, y: %{x: 2}]} = force_set([x: %{x: 1}, y: 1], all ~> px, 2)

    # Delete
    assert {:ok, %{}} = delete(%{x: 1, y: 2, z: 3}, all)
    assert {:ok, %{x: [], y: 2}} = delete(%{x: [1, 2, 3], y: 2}, px ~> all)
  end

  describe "Catching" do
    test "in any" do
      px = path(:x)
      any = Lenses.any()

      assert :error = force_set(%{}, any ~> px, 1)
      assert :error = force_set(%{k: {}}, any ~> px, 1)

      assert :error = force_set({{}}, any ~> px, 1)
      assert {:ok, {%{x: 1}}} = force_set({%{}}, any ~> px, 1)

      assert :error = force_set([x: {}], any ~> px, 1)
      assert :error = force_set([{}], any ~> px, 1)

      assert :error = set(%{}, any ~> px, 1)
      assert :error = set(%{k: {}}, any ~> px, 1)

      assert :error = set({{}}, any ~> px, 1)

      assert :error = set([x: {}], any ~> px, 1)
      assert :error = set([{}], any ~> px, 1)

      assert :error = delete([x: {}], px ~> any)
      assert :error = delete([x: []], px ~> any)
      assert :error = delete([x: %{}], px ~> any)

      assert :error = delete(%{}, any ~> px)
      assert :error = delete(%{x: 1}, any ~> px)
      assert :error = delete(%{y: 1}, any ~> px)
      assert :error = delete(%{x: %{y: 2}}, any ~> px)
    end

    test "in all" do
      px = path(:x)
      all = Lenses.all()

      assert {:ok, [%{x: 1}]} = force_set([{}], all ~> px, 1)
      assert {:ok, %{x: %{x: 1}}} = force_set(%{x: {}}, all ~> px, 1)
      assert {:ok, [x: %{x: 1}]} = force_set([x: {}], all ~> px, 1)
      assert {:ok, {%{x: 1}}} = force_set({{}}, all ~> px, 1)

      assert :error = set([{}], all ~> px, 1)
      assert :error = set(%{x: {}}, all ~> px, 1)
      assert :error = set([x: {}], all ~> px, 1)
      assert :error = set({{}}, all ~> px, 1)

      assert :error = delete([{}], all ~> px)
      assert :error = delete(%{x: {}}, all ~> px)
      assert :error = delete([x: {}], all ~> px)
      assert :error = delete({{}}, all ~> px)
    end
  end

  describe "some" do
    test "concatenated" do
      px = path(:x)
      pb = path(:b)
      some = Lenses.some()

      # View
      assert {:ok, 2} = view([%{y: 1}, %{x: 2}], some ~> px)
      assert {:ok, 1} = view([%{x: 1}, %{x: 2}], some ~> px)
      assert :error = view([%{z: :z}, %{y: :y}], some ~> px)
      assert :error = view([%{z: :z}, %{y: :y}], px ~> some ~> px)
      assert :error = view(%{x: [%{z: :z}, %{y: :y}]}, px ~> some ~> px)
      assert {:ok, :x} = view(%{x: [%{z: :z}, %{x: :x}]}, px ~> some ~> px)

      # Update
      assert {:ok, [%{a: 1}, %{b: 2}, %{c: 3}]} = set([%{a: 1}, %{b: 0}, %{c: 3}], some ~> pb, 2)
      assert {:ok, {%{a: 1}, %{b: 2}, %{c: 3}}} = set({%{a: 1}, %{b: 0}, %{c: 3}}, some ~> pb, 2)
      assert {:ok, %{x: %{a: 1}, y: %{b: 2}}} = set(%{x: %{a: 1}, y: %{b: 0}}, some ~> pb, 2)
      assert [x: [a: 1], y: %{b: 2}] = set!([x: [a: 1], y: %{b: 0}], some ~> pb, 2) |> Enum.sort()

      # Force update
      assert {:ok, [%{a: 1, b: 2}, %{b: 0}, %{c: 3}]} =
               force_set([%{a: 1}, %{b: 0}, %{c: 3}], some ~> pb, 2)

      assert {:ok, {%{a: 1, b: 2}, %{b: 0}, %{c: 3}}} =
               force_set({%{a: 1}, %{b: 0}, %{c: 3}}, some ~> pb, 2)

      assert {:ok, %{x: %{a: 1, b: 2}, y: %{b: 0}}} =
               force_set(%{x: %{a: 1}, y: %{b: 0}}, some ~> pb, 2)

      assert {:ok, [x: [a: 1, b: 2], y: %{b: 0}]} =
               force_set([x: [a: 1], y: %{b: 0}], some ~> pb, 2)

      assert {:ok, [%{a: 1, b: 2}]} = force_set([%{a: 1}], some ~> pb, 2)
      assert {:ok, {%{a: 1, b: 2}}} = force_set({%{a: 1}}, some ~> pb, 2)

      assert {:ok, [x: %{a: 1, b: 2}, y: %{c: 3}]} =
               force_set([x: %{a: 1}, y: %{c: 3}], some ~> pb, 2)

      result = force_set(%{x: [a: 1], y: %{c: 3}}, some ~> pb, 2)
      assert result in [{:ok, %{x: [a: 1, b: 2], y: %{c: 3}}}, {:ok, %{x: [a: 1], y: %{b: 2, c: 3}}}]

      # Delete
      assert {:ok, %{x: [2, 3]}} = delete(%{x: [1, 2, 3]}, px ~> some)
      assert {:ok, [1, %{}, 2, 3]} = delete([1, %{x: 1}, 2, 3], some ~> px)
    end

    test "just" do
      some = Lenses.some()
      inc = fn x -> x + 1 end

      # View
      assert {:ok, 1} = view([1, 2], some)
      assert {:ok, 2} = view(%{x: 2, y: -2}, some)
      assert {:ok, 3} = view([y: 3, z: 123], some)
      assert {:ok, 4} = view({4, 5}, some)

      # Update
      assert {:ok, [1, 123]} = over([0, 123], some, inc)
      assert {:ok, %{x: 124, y: -1}} = over(%{x: 123, y: -1}, some, inc)

      # Delete
      assert {:ok, [1, 2, 3]} = delete([0, 1, 2, 3], some)
    end
  end

  describe "conditional lenses (aka prisms)" do
    test "deletion is not working for conditional lenses" do
      m = Lenses.matching(_)
      f = Lenses.filtering(fn _ -> true end)

      assert :error = delete(%{x: 1}, m)
      assert :error = delete(%{x: 1}, f)
    end

    test "matching" do
      ml1 = Lenses.matching({:ok, _})

      assert {:ok, {:ok, 1}} == view({:ok, 1}, ml1)
      assert :error == view({:error, 1}, ml1)

      ml2 = Lenses.matching({:ok, 1})

      assert {:ok, {:ok, 1}} == view({:ok, 1}, ml2)
      assert :error == view({:ok, 2}, ml2)
      assert :error == view({:error, 1}, ml2)

      ml3 = Lenses.matching(_)

      anythings = [
        [],
        %{},
        {},
        1,
        2,
        3,
        :a,
        [x: 1, y: %{x: 2}],
        -1,
        nil,
        %MapSet{},
        true,
        false
      ]

      for anything <- anythings do
        assert {:ok, anything} === view(anything, ml3)
      end
    end

    test "matching with variable" do
      f = fn x ->
        Lenses.matching({^x, _})
      end

      okl = f.(:ok)
      assert {:ok, _} = view({:ok, 1}, okl)
      assert :error == view({:x, 1}, okl)
      assert :error == view(:ok, okl)
      assert :error == view(1, okl)
    end

    test "filtering" do
      fl1 = Lenses.filtering(fn %{h: height, w: width} -> height * width < 1000 end)

      assert {:ok, %{h: 10, w: 10}} == view(%{h: 10, w: 10}, fl1)
      assert :error == view(%{h: 10, w: 100}, fl1)

      fl2 = Lenses.filtering(fn _ -> true end)

      anythings = [
        [],
        %{},
        {},
        1,
        2,
        3,
        :a,
        [x: 1, y: %{x: 2}],
        -1,
        nil,
        %MapSet{},
        true,
        false
      ]

      for anything <- anythings do
        assert {:ok, anything} === view(anything, fl2)
      end
    end
  end

  describe "Prisms force_update" do
    test "matching" do
      assert 123 = Pathex.force_set! 0, Lenses.matching(_), 123
      assert 123 = Pathex.force_set! 0, Lenses.matching(x when x != 0), 123
    end

    test "filtering" do
      assert 123 = Pathex.force_set! 0, Lenses.filtering(fn _ -> true end), 123
      assert 123 = Pathex.force_set! 0, Lenses.filtering(& &1 != 0), 123
    end
  end
end
