defmodule Pathex.UsingTest do
  use ExUnit.Case

  defmodule JsonUsed do
    use Pathex, default_mod: :json

    def p do
      path(:x / 0)
    end

    def inlined_ok do
      Pathex.view(%{x: [1]}, path(:x / 0))
    end

    def inlined_error do
      Pathex.view(%{x: {1}}, path(:x / 0))
    end
  end

  defmodule EmptyUsed do
    use Pathex

    def p do
      path(:x / 0)
    end
  end

  defmodule NaiveUsed do
    use Pathex

    def p do
      path(:x / 0)
    end
  end

  defmodule MapUsed do
    use Pathex, default_mod: :map

    def inlined do
      [
        Pathex.view(%{x: %{y: 1}}, path(:x / :y)),
        Pathex.view([x: %{y: 1}], path(:x / :y)),
        Pathex.view(%{x: [y: 1]}, path(:x / :y))
      ]
    end
  end

  require Pathex
  import Pathex

  test "Testing if path is really a json path" do
    p = JsonUsed.p()

    assert {:ok, 1} = JsonUsed.inlined_ok()
    assert :error = JsonUsed.inlined_error()
    assert {:ok, 1} = view(%{x: [1]}, p)
    assert :error = view(%{x: {1}}, p)
    assert :error = view(%{x: {1}}, p)
    assert :error = view([x: [1]], p)
  end

  test "Testing if path is really a naive path" do
    p = NaiveUsed.p()

    assert {:ok, 1} = view(%{x: [1]}, p)
    assert {:ok, 1} = view(%{x: {1}}, p)
    assert {:ok, 1} = view([x: [1]], p)
  end

  test "Defaults to naive" do
    p = EmptyUsed.p()

    assert {:ok, 1} = view(%{x: [1]}, p)
    assert {:ok, 1} = view(%{x: {1}}, p)
    assert {:ok, 1} = view([x: [1]], p)
  end

  test "Inlined paths work correctly" do
    assert [
             {:ok, 1},
             :error,
             :error
           ] == MapUsed.inlined()
  end
end
