defmodule Pathex.MixProject do
  use Mix.Project

  def project do
    [
      app: :pathex,
      version: "0.2.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
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

  defp deps() do
    [
      {:ex_doc, "~> 0.21.3", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev], runtime: false},
      {:credo, "~> 1.1", only: [:dev], runtime: false}
    ]
  end
end
