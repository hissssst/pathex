defmodule Pathex.Test do

  require Pathex
  import Pathex

  def f do
    func = ~P[:x/:y/:z/3/2/:x]naive

    str = %{
      x: %{
        y: %{
          z: [1, 2, 3, {4, 5, %{x: 1}}]
        }
      }
    }
    func.(str)
  end
end
