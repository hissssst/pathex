defmodule GuideLensesTest do
  use ExUnit.Case

  use Pathex
  import Pathex.Lenses

  test "guiles star example" do
    users = [
      %{fname: "John", sname: "Doe", role: "CEO", access: ["admin_page", "users_page"]},
      %{fname: "Mike", sname: "Lee", role: "admin", access: ["users_page"]},
      %{fname: "Fred", sname: "Can", role: "admin", access: ["users_page"]},
      %{fname: "Dave", sname: "Lee", role: "user", access: []}
    ]

    should = [
      %{fname: "John", sname: "Doe", role: "CEO", access: ["admin_page", "users_page"]},
      %{fname: "Mike", sname: "Lee", role: "admin", access: ["admin_page", "users_page"]},
      %{fname: "Fred", sname: "Can", role: "admin", access: ["admin_page", "users_page"]},
      %{fname: "Dave", sname: "Lee", role: "user", access: []}
    ]

    adminl = matching(%{role: "admin"})
    accessl = path(:access)

    assert {:ok, new_users} =
             Pathex.over(users, star() ~> adminl ~> accessl, &["admin_page" | &1])

    assert new_users == should
  end
end
