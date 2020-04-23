defmodule PathexTest do
  use ExUnit.Case
  doctest Pathex

  require Pathex
  import Pathex

  test "view: naive sigil path: binary" do
    path = ~P["hey"]naive
    assert {:ok, true} = view path, %{"hey" => true}
    assert :error = view path, %{}
    assert :error = view path, %{hey: true}
    assert :error = view path, [{:hey, true}, {"hey", true}]
    assert :error = view path, {1, 2, 3, 4, 5}
    assert :error = view path, [1, 2, 3, 4, 5]
  end

  test "view: naive sigil path: atom" do
    path = ~P[:hey]naive
    assert {:ok, true} = view path, %{hey: true}
    assert {:ok, true} = view path, [hey: true]
    assert :error = view path, %{"hey" => true}
    assert :error = view path, [{"hey", true}]
  end

  test "view: naive sigil path: integer" do
    path = ~P[1]naive
    assert {:ok, 2} = view path, [1, 2, 3]
    assert {:ok, 2} = view path, {1, 2, 3}
    assert {:ok, :x} = view path, %{1 => :x}
    assert :error = view path, [{1, :x}]
    assert :error = view path, [0]
    assert :error = view path, {0}
  end

  test "view: naive sigil: composed easy" do
    path = ~P[1/:x/"y"]naive
    assert {:ok, 123} = view path, [1, [x: %{"y" => 123}], 2, 3]
    assert {:ok, 123} = view path, {1, [x: %{"y" => 123}], 2, 3}
    assert {:ok, 123} = view path, %{1 => [x: %{"y" => 123}], 2 => 3}
    assert {:ok, 123} = view path, %{1 => %{x: %{"y" => 123}}, 2 => 3}
    assert :error = view path, [1, [x: %{y: 123}], 2, 3]
    assert :error = view path, [1, [x: 123], 2, 3]
    assert :error = view path, [1, 123, 2, 3]
  end

  test "view: naive sigil: composed hard" do
    path = ~P[1/2/:x/3/4/"y"/:z/:z/:z/1]naive
    assert {:ok, :yay!} = view path, %{
      1 => [1, 2, %{
        x: [1, 2, 3, [1, 2, 3, 4, %{
          "y" => [
            z: [z: %{z: [1, :yay!]}],
            z: [z: %{z: [1, :nope]}]
          ]
        }]]
      }]
    }
  end

  test "view: json sigil: binary" do
    path = ~P[hey]json
    assert {:ok, "hello sir"} = view path, %{"hey" => "hello sir"}
    assert :error = view path, [{"hey", "hello sir"}]
    assert :error = view path, [hey: "this is wrong"]
  end

  test "view: json sigil: integer" do
    path = ~P[1]json
    assert {:ok, "here"} = view path, %{"1" => "here"}
    assert {:ok, "here"} = view path, ["1", "here"]
    assert {:ok, "here"} = view path, %{1 => "here"}
    #TODO: JSON specification does not allow integers to be map keys
    assert :error = view path, ["here"]
    assert :error = view path, %{}
  end

  test "view: json sigil: composed easy" do
    path = ~P[hey/1]json
    assert {:ok, "yay!"} = view path, %{"hey" => [1, "yay!"]}
    assert {:ok, "yay!"} = view path, %{"hey" => %{1 => "yay!"}}
    assert :error = view path, %{"hey" => {1, "yay!"}}
    assert :error = view path, [{"hey", [1, "yay!"]}]
  end

  test "view: json sigil: composed hard" do
    path = ~P[hey/1/1/1/x/y/z]json
    assert {:ok, "yay!"} = view path, %{
      "hey" => [0, [0, [0, %{"x" => %{"y" => %{"z" => "yay!"}}}]]]
    }
  end
end
