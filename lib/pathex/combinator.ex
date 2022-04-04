defmodule Pathex.Combinator do
  @moduledoc """
  Y-Combinator but for lenses
  """

  use Pathex

  @spec y((Pathex.t() -> Pathex.t())) :: Pathex.t()
  def y(lens_func) do
    gen(fn make_recursive_lens ->
      make_recursive_lens
      |> wrapper()
      |> lens_func.()
    end)
  end

  defp wrapper(make_recursive_lens) do
    fn
      op, argtuple when op in ~w[view update]a ->
        recursive_lens = gen(make_recursive_lens)
        recursive_lens.(op, argtuple)

      :inspect, _ ->
        #FIXME
        "y-wrapper"
    end
  end

  defp gen(make_recursive_lens) do
    make_recursive_lens.(make_recursive_lens)
  end

end
