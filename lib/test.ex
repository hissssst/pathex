defmodule Pathex.Test do

  require Pathex
  import Pathex

  def f(s, x) do
    path1 = path "hey"
    path2 = path 1

    func = path1 ~> path2

    [
      func.(:get, {s}),
      func.(:set, {s, 123})
    ]
  end

end
