defmodule Pathex.UsingTest do
  use ExUnit.Case

  defmodule Used do
    use Pathex, default_mod: :json

    def p do
      path :x / 0
    end
  end

  require Pathex
  import Pathex

  test "Testing if path is really a json path" do
    p = Used.p()

    assert {:ok, 1} = view %{x: [1]}, p
    assert :error   = view %{x: {1}}, p
    assert :error   = view [x: [1]], p
  end
end
