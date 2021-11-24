defmodule Pathex.UsingTest do
  use ExUnit.Case

  defmodule JsonUsed do
    use Pathex, default_mod: :json

    def p do
      path(:x / 0)
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

  require Pathex
  import Pathex

  test "Testing if path is really a json path" do
    p = JsonUsed.p()

    assert {:ok, 1} = view(%{x: [1]}, p)
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
end
