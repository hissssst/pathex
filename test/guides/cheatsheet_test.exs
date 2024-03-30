defmodule Pathex.CheatsheetTest do
  use ExUnit.Case
  use Pathex
  import Pathex.Combinator
  import Pathex.Lenses

  test "Leaves" do
    leaves =
      combine(fn recursive ->
        star() ~> (recursive ||| matching(_))
      end)

    assert {:ok, result} =
             %{
               x: 1,
               y: 2,
               meta: %{
                 type: :dot,
                 id: 1234
               }
             }
             |> Pathex.view(leaves)

    assert Enum.sort(List.flatten(result)) == [1, 2, 1234, :dot]
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

  test "Walk" do
    walking = postwalking(star(), matching(%{}))

    assert {:ok,
            %{
              size: 3,
              x: 1,
              y: 2,
              meta: %{
                type: :dot,
                id: 1234,
                size: 3,
                empty_map_in_list: [[[%{size: 0}]]]
              }
            }} ==
             %{
               x: 1,
               y: 2,
               meta: %{
                 type: :dot,
                 id: 1234,
                 empty_map_in_list: [[[%{}]]]
               }
             }
             |> Pathex.over(walking, &Map.put(&1, :size, map_size(&1)))
  end
end
