defmodule PathexTest do

  use ExUnit.Case

  doctest Pathex

  require Pathex
  import Pathex

  test "view: naive sigil path: binary" do
    path = ~P["hey"]naive
    assert {:ok, true} = view %{"hey" => true}, path
    assert :error = view %{}, path
    assert :error = view %{hey: true}, path
    assert :error = view [{:hey, true}, {"hey", true}], path
    assert :error = view {1, 2, 3, 4, 5}, path
    assert :error = view [1, 2, 3, 4, 5], path
  end

  test "view: naive sigil path: atom" do
    path = ~P[:hey]naive
    assert {:ok, true} = view %{hey: true}, path
    assert {:ok, true} = view [hey: true], path
    assert :error = view %{"hey" => true}, path
    assert :error = view [{"hey", true}], path
  end

  test "view: naive sigil path: integer" do
    path = ~P[1]naive
    assert {:ok, 2}  = view [1, 2, 3], path
    assert {:ok, 2}  = view {1, 2, 3}, path
    assert {:ok, :x} = view %{1 => :x}, path
    assert :error = view [{1, :x}], path
    assert :error = view [0], path
    assert :error = view {0}, path
  end

  test "view: naive sigil: composed easy" do
    path = ~P[1/:x/"y"]naive
    assert {:ok, 123} = view [1, [x: %{"y" => 123}], 2, 3], path
    assert {:ok, 123} = view {1, [x: %{"y" => 123}], 2, 3}, path
    assert {:ok, 123} = view %{1 => [x: %{"y" => 123}], 2 => 3}, path
    assert {:ok, 123} = view %{1 => %{x: %{"y" => 123}}, 2 => 3}, path
    assert :error     = view [1, [x: %{y: 123}], 2, 3], path
    assert :error     = view [1, [x: 123], 2, 3], path
    assert :error     = view [1, 123, 2, 3], path
  end

# Commented, not skipped because compilation takes a lot of time
# test "view: naive sigil: composed hard" do
#   path = ~P[1/2/:x/3/4/"y"/:z/:z/:z/1]naive
#   assert {:ok, :yay!} = view path, %{
#     1 => [1, 2, %{
#       x: [1, 2, 3, [1, 2, 3, 4, %{
#         "y" => [
#           z: [z: %{z: [1, :yay!]}],
#           z: [z: %{z: [1, :nope]}]
#         ]
#       }]]
#     }]
#   }
# end

  test "view: json sigil: binary" do
    path = ~P[hey]json
    assert {:ok, "hello sir"} = view %{"hey" => "hello sir"}, path
    assert :error = view [{"hey", "hello sir"}], path
    assert :error = view [hey: "this is wrong"], path
  end

  test "view: json sigil: integer" do
    path = ~P[1]json
    assert {:ok, "here"} = view %{"1" => "here"}, path
    assert {:ok, "here"} = view ["1", "here"], path

    #JSON specification does not allow integers to be map keys
    assert :error = view %{1 => "here"}, path
    assert :error = view ["here"], path
    assert :error = view %{}, path
  end

  test "view: json sigil: composed easy" do
    path = ~P[hey/1]json
    assert {:ok, "yay!"} = view %{"hey" => [1, "yay!"]}, path
    assert :error = view %{"hey" => %{1 => "yay!"}}, path
    assert :error = view %{"hey" => {1, "yay!"}}, path
    assert :error = view [{"hey", [1, "yay!"]}], path
  end

# test "view: json sigil: composed hard" do
#   path = ~P[hey/1/1/1/x/y/z]json
#   assert {:ok, "yay!"} = view path, %{
#     "hey" => [0, [0, [0, %{"x" => %{"y" => %{"z" => "yay!"}}}]]]
#   }
# end

  test "view: path: easy" do
    path = path 1 / :x / 3
    assert {:ok, 0} = view %{1 => [x: [1, 2, 3, 0]]}, path
    assert :error   = view %{1 => [x: [1, 2, 3]]}, path
    assert {:ok, 0} = view {1, %{x: %{3 => 0}}}, path
    assert :error   = view [{1, %{x: [1, 2, 3, 4]}}], path
    assert :error   = view %{1 => %{x: [{3, 1}]}}, path
  end

  test "view: path: with variable" do
    variable = :x
    p = path :x / variable
    assert {:ok, 1} = view %{x: %{x: 1}}, p
    assert {:ok, 1} = view %{variable => %{variable => 1}}, p
    assert :error   = view %{{:variable, [], Elixir} => %{x: 1}}, p
    assert :error   = view %{{:variable, [], nil} => %{x: 1}}, p
    variable = :y
    assert {:ok, 1} = view %{x: %{x: 1}}, p
    assert :error   = view %{x: %{y: 1}}, p
    assert :error   = view %{y: %{y: 1}}, p
    assert :error   = view %{variable => %{variable => 1}}, p
  end

  test "view: path: variable no index" do
    variable = 1
    p = path variable / :x
    assert {:ok, 0} = view %{1 => [x: 0]}, p
    assert :error   = view [{1, [x: 0]}], p
    assert {:ok, 0} = view [1, [x: 0]], p
    assert {:ok, 0} = view {1, [x: 0]}, p
  end

  test "force_set: path: easy" do
    p = path :x / :y / 1
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set %{}, p, 0
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set %{x: %{}}, p, 0
    assert {:ok, %{x: %{y: %{1 => 0}}}} == force_set %{x: %{y: %{}}}, p, 0

    assert {:ok, %{x: %{y: {1, 0}}}}    == force_set %{x: %{y: {1, 2}}}, p, 0
    assert {:ok, %{x: %{y: [1, 0]}}}    == force_set %{x: %{y: [1, 2]}}, p, 0
    assert {:ok, %{x: %{y: [0]}}}       == force_set %{x: %{y: []}}, p, 0
    assert {:ok, %{x: %{y: {0}}}}       == force_set %{x: %{y: {}}}, p, 0
  end

  test "force_set: path: list append" do
    p = path :x / :y / -1
    assert {:ok, %{x: %{y: [0, 1, 2]}}}  == force_set %{x: %{y: [1, 2]}}, p, 0
    assert {:ok, %{x: %{y: [0]}}}        == force_set %{x: %{y: []}}, p, 0
    assert {:ok, %{x: %{y: %{-1 => 0}}}} == force_set %{x: %{}}, p, 0
  end

  test "force_set: path: tricky" do
    p = path :x / :y / :z
    assert {:ok, %{x: %{z: 1, y: %{z: 0}}}} = force_set %{x: %{z: 1}}, p, 0
    assert {:ok, %{x: %{y: %{z: 0}}}}       = force_set %{x: %{y: %{z: 1}}}, p, 0
    assert {:ok, [x: [z: 1, y: %{z: 0}]]}   = force_set [x: [z: 1]], p, 0
    assert {:ok, [x: [y: [z: 0]]]} =
      force_set [x: [y: [z: 1, z: 2], y: 2], x: 2], p, 0
  end

  test "force_set: path: composition" do
    p1 = path :x
    p2 = path :y
    p = p1 ~> p2
    assert {:ok, %{x: %{y: 0}}} = force_set %{}, p, 0
    assert {:ok, %{x: %{y: 0}}} = force_set %{x: %{}}, p, 0
    assert {:ok, %{x: %{y: 0}}} = force_set %{x: %{y: 1}}, p, 0

    assert {:ok, [x: %{y: 0}]}  = force_set [], p, 0
    assert {:ok, [x: [y: 0]]}   = force_set [x: []], p, 0
    assert {:ok, [x: [y: 0]]}   = force_set [x: [y: 1]], p, 0
  end

  test "force_set: path: composition 3" do
    p1 = path :x
    p2 = path :y
    p3 = path :z
    p = p1 ~> p2 ~> p3
    assert {:ok, %{x: %{y: %{z: 0}}}} = force_set %{}, p, 0
    assert {:ok, %{x: %{y: %{z: 0}}}} = force_set %{x: %{}}, p, 0
    assert {:ok, %{x: %{y: %{z: 0}}}} = force_set %{x: %{y: %{}}}, p, 0
    assert {:ok, %{x: %{y: %{z: 0}}}} = force_set %{x: %{y: %{z: 1}}}, p, 0

    assert {:ok, [x: %{y: %{z: 0}}]}  = force_set [], p, 0
    assert {:ok, [x: [y: %{z: 0}]]}   = force_set [x: []], p, 0
    assert {:ok, [x: [y: [z: 0]]]}    = force_set [x: [y: []]], p, 0
    assert {:ok, [x: [y: [z: 0]]]}    = force_set [x: [y: [z: 1]]], p, 0
  end

  test "view: map path" do
    p1 = path :x / :y, :map
    assert {:ok, 1} == view %{x: %{y: 1}}, p1
  end

  test "inline view" do
    assert {:ok, 1} == view %{x: %{y: 1}}, path(:x / :y)
  end

  test "inline set" do
    assert {:ok, %{x: %{y: 2}}} == set %{x: %{y: 1}}, path(:x / :y), 2
  end

  test "inline force_set" do
    assert {:ok, %{x: 1}} == force_set %{x: 0}, path(:x), 1
    assert {:ok, %{x: 1}} == force_set %{}, path(:x), 1
    assert {:ok, %{x: %{y: 1}}} == force_set %{}, path(:x / :y), 1
  end

  test "set: path" do
    p = path :x / :y

    assert {:ok, %{x: %{y: 2}}} == set %{x: %{y: 1}}, p, 2
    assert :error == set %{x: %{z: 1}}, p, 2
    assert {:ok, %{x: %{y: 2, z: 3}}} == set %{x: %{y: 1, z: 3}}, p, 2
  end

  test "set: path: composition" do
    p1 = path :x / :y
    p2 = path :z

    p = p1 ~> p2

    assert {:ok, %{x: %{y: %{z: 2}}}} == set %{x: %{y: %{z: 1}}}, p, 2
    assert :error == set %{x: %{y: 1}}, p, 2
    assert {:ok, %{x: %{y: %{z: 2}, z: 3}}} == set %{x: %{z: 3, y: %{z: 1}}}, p, 2
  end

  test "view: path: double composition" do
    p1 = path :x
    p2 = path :y

    p = p1 ~> p2

    assert {:ok, 1} = view %{x: %{y: 1}}, p
    assert :error = view %{x: %{}}, p
    assert :error = view %{}, p
  end

  test "view: path: triple composition" do
    px = path :x
    p = px ~> px ~> px

    assert {:ok, 1} = view %{x: %{x: %{x: 1}}}, p
    assert :error = view %{x: %{x: %{}}}, p
    assert :error = view %{x: %{}}, p
    assert :error = view %{}, p
  end

  test "force set: path map: triple composition" do
    px = path :x, :map
    p = px ~> px ~> px

    assert {:ok, 1} = view %{x: %{x: %{x: 1}}}, p
    assert :error = view %{x: %{x: %{}}}, p
    assert :error = view %{x: %{}}, p
    assert :error = view %{}, p
  end

  test "tricky path" do
    x = :x
    p = path {:x, [], nil}
    assert {:ok, 1} = view(%{{:x, [], nil} => 1, :x => 2}, p)
  end

end
