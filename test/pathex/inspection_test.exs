defmodule Pathex.InspectionTest do
  use ExUnit.Case
  import Pathex

  test "just works" do
    p = path(1)
    assert Pathex.inspect(p) == "path(1)"
  end

  describe "With variable" do
    test "known at runtime" do
      x = 1
      p = path(x)
      assert Pathex.inspect(p) == "path(1)"
    end

    test "multiple args" do
      x = 1
      p = path(x / :y)
      assert Pathex.inspect(p) == "path(1 / :y)"
    end

    test "variable repeated" do
      x = 1
      p = path(x / x)
      assert Pathex.inspect(p) == "path(1 / 1)"
    end
  end

  describe "Lens" do
    import Pathex.Lenses
    import Pathex.Lenses.Recur

    test "zero-arity lenses" do
      assert "all()" == Pathex.inspect(all())
      assert "any()" == Pathex.inspect(any())
      assert "some()" == Pathex.inspect(some())
      assert "star()" == Pathex.inspect(star())
    end

    test "non-zero arity lenses" do
      assert "matching(_)" == Pathex.inspect(matching(_))
      assert "filtering(true)" == Pathex.inspect(filtering(true))
      assert "recur(path(1))" == Pathex.inspect(recur(path(1)))
    end
  end

  describe "Composition" do
    import Pathex.Lenses
    import Pathex.Lenses.Recur

    test "~>" do
      assert "all() ~> path(1)" == Pathex.inspect(all() ~> path(1))

      x = 2
      assert "path(2) ~> path(1)" == Pathex.inspect(path(x) ~> path(1))

      assert "all() ~> star() ~> some()" == Pathex.inspect(all() ~> star() ~> some())
    end

    test "&&&" do
      assert "all() &&& path(1)" == Pathex.inspect(all() &&& path(1))

      x = 2
      assert "path(2) &&& path(1)" == Pathex.inspect(path(x) &&& path(1))

      assert "all() &&& star() &&& some()" == Pathex.inspect(all() &&& star() &&& some())
    end

    test "|||" do
      assert "all() ||| path(1)" == Pathex.inspect(all() ||| path(1))

      x = 2
      assert "path(2) ||| path(1)" == Pathex.inspect(path(x) ||| path(1))

      assert "all() ||| star() ||| some()" == Pathex.inspect(all() ||| star() ||| some())
    end

  end
end
