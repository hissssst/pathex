defmodule Pathex.PatternTest do
  use ExUnit.Case
  use Pathex
  import Pathex

  defmacrop noassert({:"=", _, [l, r]}) do
    quote do
      assert(false == case unquote(r) do
        unquote(l) -> true
        _ -> false
      end)
    end
  end

  defp compiles(body) do
    quote do
      try do
        Code.eval_quoted(unquote(Macro.escape body), [], __ENV__)
        true
      rescue
        CompileError ->
          false
      end
    end
  end

  defmacrop assert_nocompile(do: body) do
    quote do: assert not unquote compiles body
  end

  defmacrop assert_compile(do: body) do
    quote do: assert unquote compiles body
  end

  describe "pattern" do
    test "without mod" do
      assert   pattern(path("x" / "y")) = %{"x" => %{"y" => 1}}
      noassert pattern(path("x" / "z")) = %{"x" => %{"y" => 1}}
    end

    test "with mod" do
      assert   pattern(path(:x / :y, :json)) = %{x: %{y: 1}}
      assert   pattern(path(:x / :y, :map))  = %{x: %{y: 1}}
      
      noassert pattern(path(:x / :z, :json)) = %{x: %{y: 1}}
      noassert pattern(path(:z / :y, :map))  = %{x: %{y: 1}}
    end

    test "compile error" do
      assert_nocompile do
        pattern(path(1 / 2)) = %{1 => %{2 => 3}}
      end

      assert_compile do
        pattern(path(1 / 2, :json)) = [0, [1, 2, 3]]
      end
    end
  end

end
