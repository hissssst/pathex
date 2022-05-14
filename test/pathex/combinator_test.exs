defmodule Pathex.CombinatorTest do
  use ExUnit.Case

  doctest Pathex.Combinator, import: true

  import Pathex
  import Pathex.Lenses
  import Pathex.Combinator

  test "no exit" do
    xx = combine(fn xx -> path(:x) ~> xx end)
    assert :error = Pathex.view(%{x: %{x: 1}}, xx)
    assert :error = Pathex.delete(%{x: %{x: 1}}, xx)
    assert :error = Pathex.set(%{x: %{x: 1}}, xx, 2)
  end

  test "inspection" do
    x = 1

    rec =
      combine(fn rec ->
        y = 2
        path(:x / x / y) ~> rec ~> path(:z)
      end)

    result =
      quote do
        combine(fn recursive ->
          path(:x / 1 / 2) ~> recursive ~> path(:z)
        end)
      end
      |> Macro.to_string()

    assert result == Pathex.inspect(rec)
  end

  test "from doc" do
    document =
      {"html",
       [
         {"head", []},
         {"body",
          [
            {"div",
             [
               {"label", "well"},
               {"label", "Hey, please click subscribe button"}
             ]}
          ]}
       ]}

    path_to_subscribe =
      combine(fn recursive -> some() ~> (recursive ||| matching(_)) end)
      # To find a label
      ~> matching({"label", _})
      # To get to value of a label
      ~> path(1)
      ~> filtering(&String.ends_with?(&1, "please click subscribe button"))

    assert {:ok, new_document} = Pathex.set(document, path_to_subscribe, "Do not subscribe, hehe")

    assert new_document ==
             {"html",
              [
                {"head", []},
                {"body",
                 [
                   {"div",
                    [
                      {"label", "well"},
                      {"label", "Do not subscribe, hehe"}
                    ]}
                 ]}
              ]}
  end

  test "leaves" do
    leaves = combine(fn recursive -> star() ~> (recursive ||| matching(_)) end)
    assert {:ok, [1, 2, 3]} = Pathex.view([1, 2, 3], leaves)
    assert :error = Pathex.view([], leaves)
    assert [1, 2, 3] = Pathex.view!([1, [2, 3]], leaves) |> List.flatten()
    assert [1, 2, 3] = Pathex.view!([1, %{x: [2, %{x: 3}]}], leaves) |> List.flatten()
  end

  def postwalking(iterlens, predicate) do
    combine(fn recursive ->
      predicate
      ~> (alongside([
            iterlens ~> recursive,
            matching(_)
          ]) |||
            matching(_)) |||
        iterlens ~> recursive
    end)
  end

  test "postwalking" do
    walking = postwalking(star(), matching(%{}))

    Process.put(:x, 0)

    assert [
             1,
             2,
             3,
             4,
             [
               [
                 [
                   %{
                     x: 1,
                     map: %{}
                   }
                 ]
               ]
             ]
           ] =
             Pathex.over!([1, 2, 3, 4, [[[%{x: 1}]]]], walking, fn map ->
               x = Process.get(:x)

               if x < 3 do
                 Process.put(:x, x + 1)
                 Map.put(map, :map, %{})
               else
                 map
               end
             end)
  end

  def prewalking(iterlens, predicate) do
    combine(fn recursive ->
      predicate
      ~> (alongside([
            matching(_),
            iterlens ~> recursive
          ]) |||
            matching(_)) |||
        iterlens ~> recursive
    end)
  end

  test "prewalking" do
    walking = prewalking(star(), matching(%{}))

    Process.put(:x, 0)

    assert [
             1,
             2,
             3,
             4,
             [
               [
                 [
                   %{
                     x: 1,
                     map: %{map: %{map: %{}}}
                   }
                 ]
               ]
             ]
           ] =
             Pathex.over!([1, 2, 3, 4, [[[%{x: 1}]]]], walking, fn map ->
               x = Process.get(:x)

               if x < 3 do
                 Process.put(:x, x + 1)
                 Map.put(map, :map, %{})
               else
                 map
               end
             end)
  end
end
