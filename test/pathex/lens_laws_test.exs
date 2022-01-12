defmodule Pathex.LensLawsTest do
  use ExUnit.Case
  use Pathex
  import Pathex.Lenses

  def test_set_get(lens, structure, value) do
    {:ok, new_structure} = Pathex.set(structure, lens, value)
    {:ok, got_value} = Pathex.view(new_structure, lens)

    assert got_value === value
  end

  def test_set_set(lens, structure, value_a, value_b) do
    {:ok, structure_with_a} = Pathex.set(structure, lens, value_a)

    {:ok, structure_with_b} = Pathex.set(structure, lens, value_b)
    {:ok, structure_with_a_after_b} = Pathex.set(structure_with_b, lens, value_a)

    assert structure_with_a_after_b === structure_with_a
  end

  def test_get_set(lens, structure) do
    {:ok, value} = Pathex.view(structure, lens)
    {:ok, structure_with_value_set} = Pathex.set(structure, lens, value)

    assert structure_with_value_set === structure
  end

  describe "Non-collection lenses" do
    test "naive" do
      pxyz = path(:x / :y / :z)
      structure = %{x: %{y: %{z: 1}}, x1: %{y: %{z: 2}}}

      test_set_get(pxyz, structure, 2)
      test_set_set(pxyz, structure, 2, 3)
      test_get_set(pxyz, structure)
    end

    test "some" do
      structures = [
        [:a, :b, %{c: :d}, [e: :f], :g],
        %{x: :a, y: :b, z: [:c, :d, [e: :f], :g]}
      ]

      for structure <- structures do
        test_set_get(some(), structure, 1)
        test_set_set(some(), structure, 1, 2)
        test_get_set(some(), structure)
      end
    end

    test "any" do
      structures = [
        [:a, :b, %{c: :d}, [e: :f], :g],
        %{x: :a, y: :b, z: [:c, :d, [e: :f], :g]}
      ]

      for structure <- structures do
        test_set_get(any(), structure, 1)
        test_set_set(any(), structure, 1, 2)
        test_get_set(any(), structure)
      end
    end
  end

  def test_collection_set_get(lens, structure, value) do
    {:ok, new_structure} = Pathex.set(structure, lens, value)
    {:ok, got_values} = Pathex.view(new_structure, lens)

    assert Enum.all?(got_values, &(&1 === value))
  end

  def test_collection_set_set(lens, structure, value_a, value_b) do
    {:ok, structure_with_a} = Pathex.set(structure, lens, value_a)

    {:ok, structure_with_b} = Pathex.set(structure, lens, value_b)
    {:ok, structure_with_a_after_b} = Pathex.set(structure_with_b, lens, value_a)

    assert structure_with_a_after_b === structure_with_a
  end

  describe "Collection" do
    test "star" do
      structures = [
        [:a, :b, %{c: :d}, [e: :f], :g],
        %{x: :a, y: :b, z: [:c, :d, [e: :f], :g]}
      ]

      for structure <- structures do
        test_collection_set_get(star(), structure, 1)
        test_collection_set_set(star(), structure, 1, 2)
      end
    end

    test "all" do
      structures = [
        [:a, :b, %{c: :d}, [e: :f], :g],
        %{x: :a, y: :b, z: [:c, :d, [e: :f], :g]}
      ]

      for structure <- structures do
        test_collection_set_get(all(), structure, 1)
        test_collection_set_set(all(), structure, 1, 2)
      end
    end
  end
end
