defmodule Pathex.ShortTest do
  use ExUnit.Case
  doctest Pathex.Short, import: true

  defmodule JsonUsed do
    use Pathex.Short, default_mod: :json

    def p do
      :x / 0
    end

    def inlined_ok do
      Pathex.view(%{x: [1]}, :x / 0)
    end

    def inlined_error do
      Pathex.view(%{x: {1}}, :x / 0)
    end
  end

  defmodule EmptyUsed do
    use Pathex.Short

    def p do
      :x / 0
    end
  end

  defmodule NaiveUsed do
    use Pathex.Short

    def p do
      :x / 0
    end
  end

  defmodule MapUsed do
    use Pathex.Short, default_mod: :map

    def inlined do
      [
        Pathex.view(%{x: %{y: 1}}, :x / :y),
        Pathex.view([x: %{y: 1}], :x / :y),
        Pathex.view(%{x: [y: 1]}, :x / :y)
      ]
    end
  end

  defmodule InDef do
    def map do
      use Pathex.Short, default_mod: :map

      [
        Pathex.view(%{x: %{y: 1}}, :x / :y),
        Pathex.view([x: %{y: 1}], :x / :y),
        Pathex.view(%{x: [y: 1]}, :x / :y)
      ]
    end

    def naive do
      use Pathex.Short, default_mod: :naive

      [
        Pathex.view(%{x: %{y: 1}}, :x / :y),
        Pathex.view([x: %{y: 1}], :x / :y),
        Pathex.view(%{x: [y: 1]}, :x / :y)
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

  test "Can be used in def" do
    assert [
             {:ok, 1},
             :error,
             :error
           ] == InDef.map()

    assert [
             {:ok, 1},
             {:ok, 1},
             {:ok, 1}
           ] == InDef.naive()
  end
end
