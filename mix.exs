defmodule Pathex.MixProject do
  use Mix.Project

  def project do
    [
      app: :pathex,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: [ex_doc: "~> 0.21.3"],
      name: "Pathex",
      source_url: "https://github.com/hissssst/pathex"
    ]
  end

  def application, do: []

  def description do
    "Code generation library for functional lenses"
  end

  defp package() do
    [
      licenses: ["BSD-2-Clause"],
      links: %{"GitHub" => "https://github.com/hissssst/pathex"}
    ]
  end
end
