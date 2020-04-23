defmodule Pathex.Test do

  require Pathex
  import Pathex

  def f(s, x) do
    path1 = path 1
    path2 = path :x / :y

    func = path1 ~> path2 ~> path1

    [
      func.(:get, {s}),
      func.(:set, {s, x}),
      func.(:update, {s, & "xX_#{&1}_Xx"})
    ]
  end

end
