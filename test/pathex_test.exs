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

    #JSON specification does not allow integers to be map keys
    assert :error = view path, %{1 => "here"}
    assert :error = view path, ["here"]
    assert :error = view path, %{}
  end

  test "view: json sigil: composed easy" do
    path = ~P[hey/1]json
    assert {:ok, "yay!"} = view path, %{"hey" => [1, "yay!"]}
    assert :error = view path, %{"hey" => %{1 => "yay!"}}
    assert :error = view path, %{"hey" => {1, "yay!"}}
    assert :error = view path, [{"hey", [1, "yay!"]}]
  end

  test "view: json sigil: composed hard" do
    path = ~P[hey/1/1/1/x/y/z]json
    assert {:ok, "yay!"} = view path, %{
      "hey" => [0, [0, [0, %{"x" => %{"y" => %{"z" => "yay!"}}}]]]
    }
  end

  test "view: path: easy" do
    p = path 1 / :x / 3
    assert {:ok, 0} = view p, %{1 => [x: [1, 2, 3, 0]]}
    assert :error   = view p, %{1 => [x: [1, 2, 3]]}
    assert {:ok, 0} = view p, {1, %{x: %{3 => 0}}}
    assert :error   = view p, [{1, %{x: [1, 2, 3, 4]}}]
    assert :error   = view p, %{1 => %{x: [{3, 1}]}}
  end

  test "view: path: with variable" do
    variable = :x
    p = path :x / variable
    assert {:ok, 1} = view p, %{x: %{x: 1}}
    assert {:ok, 1} = view p, %{variable => %{variable => 1}}
    assert :error   = view p, %{{:variable, [], Elixir} => %{x: 1}}
    assert :error   = view p, %{{:variable, [], nil} => %{x: 1}}
    variable = :y
    assert {:ok, 1} = view p, %{x: %{x: 1}}
    assert :error   = view p, %{x: %{y: 1}}
    assert :error   = view p, %{y: %{y: 1}}
    assert :error   = view p, %{variable => %{variable => 1}}
  end

  test "view: path: variable no index" do
    variable = 1
    p = path variable / :x
    assert {:ok, 0} = view p, %{1 => [x: 0]}
    assert :error   = view p, [{1, [x: 0]}]
    assert {:ok, 0} = view p, [1, [x: 0]]
    assert {:ok, 0} = view p, {1, [x: 0]}
  end

  test "force_set: path: easy" do
    p = path :x / :y / 1
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set p, %{}, 0
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set p, %{x: %{}}, 0
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set p, %{x: %{y: %{}}}, 0

    assert {:ok, %{x: %{y: {1, 0}}}}    == force_set p, %{x: %{y: {1, 2}}}, 0
    assert {:ok, %{x: %{y: [1, 0]}}}    == force_set p, %{x: %{y: [1, 2]}}, 0
    assert {:ok, %{x: %{y: [0]}}}       == force_set p, %{x: %{y: []}}, 0
    assert {:ok, %{x: %{y: {0}}}}       == force_set p, %{x: %{y: {}}}, 0
  end

  test "force_set: path: list append" do
    p = path :x / :y / -1
    assert {:ok, %{x: %{y: [0, 1, 2]}}}  == force_set p, %{x: %{y: [1, 2]}}, 0
    assert {:ok, %{x: %{y: [0]}}}        == force_set p, %{x: %{y: []}}, 0
    assert {:ok, %{x: %{y: %{-1 => 0}}}} == force_set p, %{x: %{}}, 0
  end

  test "force_set: path: tricky" do
    p = path :x / :y / :z
    assert {:ok, %{x: %{z: 1, y: %{z: 0}}}} =   force_set p, %{x: %{z: 1}}, 0
    assert {:ok, %{x: %{y: %{z: 0}}}} = force_set p, %{x: %{y: %{z: 1}}}, 0
    assert {:ok, [x: [z: 1, y: %{z: 0}]]} = force_set p, [x: [z: 1]], 0
    assert {:ok, [x: [y: [z: 0]]]} =
      force_set p, [x: [y: [z: 1, z: 2], y: 2], x: 2], 0
  end

  test "force_set: path: composition" do
    p1 = path :x
    p2 = path :y
    p = p1 ~> p2
    assert {:ok, %{x: %{y: 0}}} = force_set p, %{}, 0
    assert {:ok, %{x: %{y: 0}}} = force_set p, %{x: %{}}, 0
    assert {:ok, %{x: %{y: 0}}} = force_set p, %{x: %{y: 1}}, 0

    assert {:ok, [x: %{y: 0}]}  = force_set p, [], 0
    assert {:ok, [x: [y: 0]]}   = force_set p, [x: []], 0
    assert {:ok, [x: [y: 0]]}   = force_set p, [x: [y: 1]], 0
  end

  test "view: map path" do
    p1 = path :x / :y, :map
    assert {:ok, 1} == view p1, %{x: %{y: 1}}
  end

  test "direct view" do
    assert {:ok, 1} == view :x / :y, %{x: %{y: 1}}
  end

  test "direct set" do
    assert {:ok, %{x: %{y: 2}}} == set :x / :y, %{x: %{y: 1}}, 2
  end
end
