defmodule Pathex.LensesTest do

  use ExUnit.Case

  doctest Pathex.Lenses

  require Pathex
  import Pathex

  test "Tricky alls" do
    px = path :x
    all = Pathex.Lenses.all()

    inc = fn x -> x + 1 end

    # View
    assert {:ok, [1, 2]} = view %{x: [1, 2]}, px ~> all
    assert {:ok, [1, 2]} = at %{x: [[x: 0], %{x: 1}]}, px ~> all ~> px, inc

    assert :error = view %{x: [%{x: 1}, %{y: 2}]}, px ~> all ~> px

    # Update
    assert {:ok, [[x: 2], [x: 3]]} = over [[x: 1], [x: 2]], all ~> px, inc
    assert {:ok, [[x: 2], %{x: 2}]} = set [[x: 1], %{x: 1}], all ~> px, 2

    assert :error = set %{x: [[x: 1], [y: 1]]}, px ~> all ~> px, 1

    # Force
    assert {:ok, [x: 2, y: 2]} = force_set [x: 1, y: 1], all, 2
    assert {:ok, [x: %{x: 2}, y: %{x: 2}]} = force_set [x: %{x: 1}, y: 1], all ~> px, 2
  end

  test "Catching in either" do
    px = path :x
    hi = Pathex.Lenses.either(:hi)

    assert :error = force_set {:hi, {}}, hi ~> px, 1
    assert :error = force_set {}, hi ~> px, 1

    assert :error = set {:hi, {}}, hi ~> px, 1
    assert :error = set {}, hi ~> px, 1
  end

  test "Catching in id" do
    px = path :x
    id = Pathex.Lenses.id()

    assert :error = force_set {}, id ~> px, 1
    assert :error = set {}, id ~> px, 1
  end

  test "Catching in any" do
    px  = path :x
    any = Pathex.Lenses.any()

    assert :error = force_set %{}, any ~> px, 1
    assert :error = force_set %{k: {}}, any ~> px, 1

    assert :error = force_set {{}}, any ~> px, 1
    assert {:ok, {%{x: 1}}}= force_set {%{}}, any ~> px, 1

    assert :error = force_set [x: {}], any ~> px, 1
    assert :error = force_set [{}], any ~> px, 1

    assert :error = set %{}, any ~> px, 1
    assert :error = set %{k: {}}, any ~> px, 1

    assert :error = set {{}}, any ~> px, 1

    assert :error = set [x: {}], any ~> px, 1
    assert :error = set [{}], any ~> px, 1
  end

  test "Catching in all" do
    px = path :x
    all = Pathex.Lenses.all()

    assert {:ok, [%{x: 1}]}     = force_set [{}], all ~> px, 1
    assert {:ok, %{x: %{x: 1}}} = force_set %{x: {}}, all ~> px, 1
    assert {:ok, [x: %{x: 1}]}  = force_set [x: {}], all ~> px, 1
    assert {:ok, {%{x: 1}}}     = force_set {{}}, all ~> px, 1

    assert :error = set [{}], all ~> px, 1
    assert :error = set %{x: {}}, all ~> px, 1
    assert :error = set [x: {}], all ~> px, 1
    assert :error = set {{}}, all ~> px, 1
  end

end
