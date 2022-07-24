defmodule Pathex.ExpressionInPathTest do
  use ExUnit.Case
  import Pathex

  def f(x), do: x + 1

  defmacro m do
    quote(do: "m")
  end

  describe "call" do
    test "just function" do
      p = path(:x / f(0) / f(1))
      assert {:ok, 1} = view(%{x: %{1 => %{2 => 1}}}, p)
      assert {:ok, 1} = view(%{x: [0, [3, 2, 1]]}, p)
      assert {:ok, [1, 2, 3]} = view([x: [0, {3, 2, [1, 2, 3]}]], p)

      assert :error = view(%{}, p)
      assert :error = view(%{x: %{}}, p)
      assert :error = view(%{x: %{1 => %{}}}, p)
      assert :error = view(%{x: %{1 => %{2.0 => 1}}}, p)
    end

    test "just macro" do
      p = path(m())

      assert {:ok, 1} = view(%{"m" => 1}, p)
      assert :error = view(%{m: 1}, p)
      assert :error = view([m: 1], p)
      assert :error = view([{"m", 1}], p)
    end
  end

  describe "special forms" do
    test "map" do
      p = path(%{x: 1} / :x)

      assert {:ok, 1} = view(%{%{x: 1} => %{x: 1}}, p)
      assert {:ok, 1} = view(%{%{x: 1} => [x: 1]}, p)
      assert :error = view([{%{x: 1}, [x: 1]}], p)
    end

    test "tuple" do
      p = path({:x, 1} / :x)

      assert {:ok, 1} = view(%{{:x, 1} => %{x: 1}}, p)
      assert {:ok, 1} = view(%{{:x, 1} => [x: 1]}, p)
      assert :error = view([{{:x, 1}, [x: 1]}], p)
    end

    test "tuple with variable" do
      v = 1
      p = path({:x, v} / :x)

      assert {:ok, 1} = view(%{{:x, 1} => %{x: 1}}, p)
      assert {:ok, 1} = view(%{{:x, 1} => [x: 1]}, p)
      assert :error = view([{{:x, 1}, [x: 1]}], p)
    end

    test "__MODULE__" do
      p = path(__MODULE__ / 0)

      assert {:ok, 1} = view([{__MODULE__, [1, 2]}], p)
      assert {:ok, 1} = view(%{__MODULE__ => [1, 2]}, p)
      assert :error = view({__MODULE__, 1, 2}, p)
      assert :error = view({__MODULE__, 1, 2}, p)
    end
  end

  describe "& closure" do
    test "refering to function" do
      px = (&path/1).(:x)

      assert {:ok, 1} = view(%{x: 1}, px)
      assert {:ok, 1} = view([x: 1], px)
      assert :error = view([], px)
    end

    test "refering to function with :map" do
      px = (&path(&1, :map)).(:x)

      assert {:ok, 1} = view(%{x: 1}, px)
      assert :error = view([x: 1], px)
      assert :error = view([], px)
    end

    test "multiple" do
      px = (&path(&1 / &2, :map)).(:x, :y)

      assert {:ok, 1} = view(%{x: %{y: 1}}, px)
      assert :error = view([x: %{y: 1}], px)
      assert :error = view(%{x: [y: 1]}, px)
      assert :error = view([], px)
    end
  end

  describe "hygiene" do
    test "variable" do
      variable = 1
      path({:ok, 1})
      assert variable == 1
    end
  end
end
