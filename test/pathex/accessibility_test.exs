defmodule Pathex.AccessibilityTest do
  use ExUnit.Case

  doctest Pathex.Accessibility, import: true

  import Pathex
  import Pathex.Accessibility

  describe "from_list/2" do
    test "just works" do
      p = from_list(~w[x y z]a)

      assert {:ok, 1} = view(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, 1} = view(%{x: %{y: [z: 1]}}, p)
      assert {:ok, 1} = view([x: %{y: %{z: 1}}], p)

      assert :error = view(%{z: %{y: %{x: 1}}}, p)
      assert :error = view(%{x: %{y: [x: 1]}}, p)
      assert :error = view([x: %{y: %{}}], p)
    end

    test "map mod" do
      p = from_list([:x, :y, 1], :map)

      assert {:ok, 2} = view(%{x: %{y: %{1 => 2}}}, p)
      assert :error = view(%{x: %{y: [0, 2]}}, p)
      assert :error = view([x: %{y: %{1 => 2}}], p)
    end
  end

  describe "from_access/1" do
    test "view" do
      p = from_access(~w[x y z]a)

      assert {:ok, 1} = view(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, 1} = view(%{x: %{y: [z: 1]}}, p)
      assert {:ok, 1} = view([x: %{y: %{z: 1}}], p)

      assert :error = view(%{z: %{y: %{x: 1}}}, p)
      assert :error = view(%{x: %{y: [x: 1]}}, p)
      assert :error = view([x: %{y: %{}}], p)
    end

    test "update" do
      p = from_access(~w[x y z]a)

      assert {:ok, %{x: %{y: %{z: 2}}}} = set(%{x: %{y: %{z: 1}}}, p, 2)
      assert {:ok, %{x: %{y: [z: 2]}}} = set(%{x: %{y: [z: 1]}}, p, 2)
      assert {:ok, [x: %{y: %{z: 2}}]} = set([x: %{y: %{z: 1}}], p, 2)

      assert :error = set(%{z: %{y: %{x: 1}}}, p, 2)
      assert :error = set(%{x: %{y: [x: 1]}}, p, 2)
      assert :error = set([x: %{y: %{}}], p, 2)
    end

    test "delete" do
      p = from_access(~w[x y z]a)

      assert {:ok, %{x: %{y: %{}}}} = delete(%{x: %{y: %{z: 1}}}, p)
      assert {:ok, %{x: %{y: []}}} = delete(%{x: %{y: [z: 1]}}, p)
      assert {:ok, [x: %{y: %{}}]} = delete([x: %{y: %{z: 1}}], p)

      assert :error = delete(%{z: %{y: %{x: 1}}}, p)
      assert :error = delete(%{x: %{y: [x: 1]}}, p)
      assert :error = delete([x: %{y: %{}}], p)
    end

    test "inspect" do
      assert "accessible([:x, :y, :z])" == Pathex.inspect(from_access(~w[x y z]a))
    end
  end

  describe "to_access/1" do
    test "get" do
      a = to_access(path(:x / :y / :z))

      assert 1 == get_in(%{x: %{y: %{z: 1}}}, a)
      assert nil == get_in(%{x: %{y: %{}}}, a)
      assert nil == get_in(%{x: %{}}, a)
      assert nil == get_in(%{}, a)
    end

    test "pop" do
      a = to_access(path(:x / :y / :z))

      assert {1, %{x: %{y: %{}}}} == pop_in(%{x: %{y: %{z: 1}}}, a)
      assert {nil, %{x: %{y: %{}}}} == pop_in(%{x: %{y: %{}}}, a)
      assert {nil, %{x: %{}}} == pop_in(%{x: %{}}, a)
      assert {nil, %{}} == pop_in(%{}, a)
    end

    test "update" do
      a = to_access(path(:x / :y / :z))
      f = &(&1 + 1)

      assert %{x: %{y: %{z: 2}}} == update_in(%{x: %{y: %{z: 1}}}, a, f)
      assert %{x: %{y: %{}}} == update_in(%{x: %{y: %{}}}, a, f)
      assert %{x: %{}} == update_in(%{x: %{}}, a, f)
      assert %{} == update_in(%{}, a, f)
    end
  end

  describe "from_struct/2" do
    defmodule X do
      @enforce_keys [:y]
      defstruct @enforce_keys ++ [:z, x: 1]
    end

    test "view" do
      x = from_struct(X, :y)

      assert :error == view(%{y: 1}, x)
      assert :error == view([y: 1], x)
      assert {:ok, 1} == view(%X{y: 1}, x)
    end

    test "update" do
      x = from_struct(X, :y)

      assert :error == set(%{y: 1}, x, 2)
      assert :error == set([y: 1], x, 2)
      assert {:ok, %X{y: 2}} == set(%X{y: 1}, x, 2)
    end

    test "force_update" do
      x = from_struct(X, :y)

      assert {:ok, %X{y: 2}} == force_set(%{y: 1}, x, 2)
      assert :error == force_set([y: 1], x, 2)
      assert :error == force_set({:y, 1}, x, 2)
      assert {:ok, %X{x: 2, y: 2}} == force_set(%{x: 2}, x, 2)
      assert {:ok, %X{y: 2}} == force_set(%X{y: 1}, x, 2)

      assert {:ok, %X{y: %X{y: 2}}} == force_set(%{}, x ~> x, 2)
    end

    test "delete" do
      # It must always fail for enforced key
      x = from_struct(X, :y)

      assert :error == delete(%{y: 1}, x)
      assert :error == delete([y: 1], x)
      assert :error == delete(%X{y: 1}, x)

      x = from_struct(X, :x)
      assert {:ok, %X{y: 1}} == delete(%X{x: -1, y: 1}, x)
      assert {:ok, %X{y: 1}} == delete(%X{y: 1}, x)
      assert :error == delete([y: 1], x)
    end

    test "inspect" do
      x = from_struct(X, :y)
      assert "from_struct(%#{Kernel.inspect(__MODULE__.X)}{}.y)" == Pathex.inspect(x)
    end
  end

  describe "from_record/3" do
    import Record

    defmodule Y do
      import Record
      defrecord(:y, x: 1, y: 2, z: 3)

      def f(x) do
        lens = from_record(__MODULE__, :y, :x)
        view(x, lens)
      end
    end

    test "in-module" do
      import Y
      assert {:ok, 1} == Y.f(y())
    end

    test "view" do
      import Y
      yl = from_record(Y, :y, :x)

      assert {:ok, 1} == view(y(), yl)
      assert {:ok, 22} == view(y(x: 22), yl)
      assert :error == view({1, 2, 3, 4}, yl)
      assert :error == view({:y, 0, 1, 2, 3, 4}, yl)
      assert :error == view({:z, 2, 3, 4}, yl)
    end

    test "update" do
      import Y
      yl = from_record(Y, :y, :x)

      assert {:ok, y(x: 0)} == set(y(), yl, 0)
      assert :error == set({1, 2, 3, 4}, yl, 0)
      assert :error == set({:y, 0, 1, 2, 3, 4}, yl, 0)
      assert :error == set({:z, 2, 3, 4}, yl, 0)
    end

    test "force_update" do
      import Y
      yl = from_record(Y, :y, :x)

      assert {:ok, y(x: 0)} == force_set(y(), yl, 0)
      assert {:ok, y(x: 0)} == force_set({}, yl, 0)
      assert {:ok, y(x: 0)} == force_set({1, 2, 3, 4}, yl, 0)
      assert :error == force_set([], yl, 0)
      assert :error == force_set(%{}, yl, 0)
    end

    test "delete" do
      import Y
      yl = from_record(Y, :y, :x)

      # Must always fail
      assert :error == delete(y(), yl)
      assert :error == delete(y(x: 22), yl)
      assert :error == delete({1, 2, 3, 4}, yl)
      assert :error == delete({:y, 0, 1, 2, 3, 4}, yl)
      assert :error == delete({:z, 2, 3, 4}, yl)
    end

    test "inspect" do
      yl = from_record(Y, :y, :x)
      assert "from_record(#{Kernel.inspect(__MODULE__.Y)}.y(:x))" == Pathex.inspect(yl)
    end
  end
end
