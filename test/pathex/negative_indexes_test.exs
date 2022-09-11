defmodule Pathex.NegativeIndexesTest do

  use ExUnit.Case, async: true
  use Pathex

  describe "view" do
    test "tuple" do
      assert 3 == Pathex.view! {1, 2, 3}, path(-1)
      assert 2 == Pathex.view! {1, 2, 3}, path(-2)
      assert 1 == Pathex.view! {1, 2, 3}, path(-3)
      assert :error == Pathex.view {1, 2, 3}, path(-4)

      x = -1; assert 3 == Pathex.view! {1, 2, 3}, path(x)
      x = -2; assert 2 == Pathex.view! {1, 2, 3}, path(x)
      x = -3; assert 1 == Pathex.view! {1, 2, 3}, path(x)
      x = -4; assert :error == Pathex.view {1, 2, 3}, path(x)
    end

    test "list" do
      assert 3 == Pathex.view! [1, 2, 3], path(-1)
      assert 2 == Pathex.view! [1, 2, 3], path(-2)
      assert 1 == Pathex.view! [1, 2, 3], path(-3)
      assert :error == Pathex.view [1, 2, 3], path(-4)

      x = -1; assert 3 == Pathex.view! [1, 2, 3], path(x)
      x = -2; assert 2 == Pathex.view! [1, 2, 3], path(x)
      x = -3; assert 1 == Pathex.view! [1, 2, 3], path(x)
      x = -4; assert :error == Pathex.view [1, 2, 3], path(x)
    end
  end

  describe "over" do
    test "tuple" do
      assert {1, 2, 0} == Pathex.set! {1, 2, 3}, path(-1), 0
      assert {1, 0, 3} == Pathex.set! {1, 2, 3}, path(-2), 0
      assert {0, 2, 3} == Pathex.set! {1, 2, 3}, path(-3), 0
      assert :error == Pathex.set {1, 2, 3}, path(-4), 0

      x = -1; assert {1, 2, 0} == Pathex.set! {1, 2, 3}, path(x), 0
      x = -2; assert {1, 0, 3} == Pathex.set! {1, 2, 3}, path(x), 0
      x = -3; assert {0, 2, 3} == Pathex.set! {1, 2, 3}, path(x), 0
      x = -4; assert :error == Pathex.set {1, 2, 3}, path(x), 0
    end

    test "list" do
      assert [1, 2, 0] == Pathex.set! [1, 2, 3], path(-1), 0
      assert [1, 0, 3] == Pathex.set! [1, 2, 3], path(-2), 0
      assert [0, 2, 3] == Pathex.set! [1, 2, 3], path(-3), 0
      assert :error == Pathex.set [1, 2, 3], path(-4), 0

      x = -1; assert [1, 2, 0] == Pathex.set! [1, 2, 3], path(x), 0
      x = -2; assert [1, 0, 3] == Pathex.set! [1, 2, 3], path(x), 0
      x = -3; assert [0, 2, 3] == Pathex.set! [1, 2, 3], path(x), 0
      x = -4; assert :error == Pathex.set [1, 2, 3], path(x), 0
    end
  end

  describe "delete" do
    test "tuple" do
      assert {1, 2} == Pathex.delete! {1, 2, 3}, path(-1)
      assert {1, 3} == Pathex.delete! {1, 2, 3}, path(-2)
      assert {2, 3} == Pathex.delete! {1, 2, 3}, path(-3)
      assert :error == Pathex.delete {1, 2, 3}, path(-4)

      x = -1; assert {1, 2} == Pathex.delete! {1, 2, 3}, path(x)
      x = -2; assert {1, 3} == Pathex.delete! {1, 2, 3}, path(x)
      x = -3; assert {2, 3} == Pathex.delete! {1, 2, 3}, path(x)
      x = -4; assert :error == Pathex.delete {1, 2, 3}, path(x)
    end

    test "list" do
      assert [1, 2] == Pathex.delete! [1, 2, 3], path(-1)
      assert [1, 3] == Pathex.delete! [1, 2, 3], path(-2)
      assert [2, 3] == Pathex.delete! [1, 2, 3], path(-3)
      assert :error == Pathex.delete [1, 2, 3], path(-4)

      x = -1; assert [1, 2] == Pathex.delete! [1, 2, 3], path(x)
      x = -2; assert [1, 3] == Pathex.delete! [1, 2, 3], path(x)
      x = -3; assert [2, 3] == Pathex.delete! [1, 2, 3], path(x)
      x = -4; assert :error == Pathex.delete [1, 2, 3], path(x)
    end
  end

  describe "force_over" do
    test "tuple" do
      assert {1, 2, 0} == Pathex.force_set! {1, 2, 3}, path(-1), 0
      assert {1, 0, 3} == Pathex.force_set! {1, 2, 3}, path(-2), 0
      assert {0, 2, 3} == Pathex.force_set! {1, 2, 3}, path(-3), 0
      assert {0, 1, 2, 3} == Pathex.force_set! {1, 2, 3}, path(-4), 0
      assert {0, nil, 1, 2, 3} == Pathex.force_set! {1, 2, 3}, path(-5), 0

      x = -1; assert {1, 2, 0} == Pathex.force_set! {1, 2, 3}, path(x), 0
      x = -2; assert {1, 0, 3} == Pathex.force_set! {1, 2, 3}, path(x), 0
      x = -3; assert {0, 2, 3} == Pathex.force_set! {1, 2, 3}, path(x), 0
      x = -4; assert {0, 1, 2, 3} == Pathex.force_set! {1, 2, 3}, path(x), 0
      x = -5; assert {0, nil, 1, 2, 3} == Pathex.force_set! {1, 2, 3}, path(x), 0
    end

    test "list" do
      # This is tricky, because `-1` always prepends to the list
      # TODO change this in 3.0
      assert [0, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(-1), 0
      assert [1, 0, 3] == Pathex.force_set! [1, 2, 3], path(-2), 0
      assert [0, 2, 3] == Pathex.force_set! [1, 2, 3], path(-3), 0
      assert [0, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(-4), 0
      assert [0, nil, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(-5), 0

      x = -1; assert [0, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(x), 0
      x = -2; assert [1, 0, 3] == Pathex.force_set! [1, 2, 3], path(x), 0
      x = -3; assert [0, 2, 3] == Pathex.force_set! [1, 2, 3], path(x), 0
      x = -4; assert [0, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(x), 0
      x = -5; assert [0, nil, 1, 2, 3] == Pathex.force_set! [1, 2, 3], path(x), 0
    end
  end

end
