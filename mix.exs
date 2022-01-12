defmodule Pathex.MixProject do
  use Mix.Project

  @version "1.2.0"

  def project do
    [
      app: :pathex,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Pathex",
      source_url: "https://github.com/hissssst/pathex",
      docs: docs(),
      # compilers:       [:unused | Mix.compilers()],
      unused: [{:_, :__using__, :_}, {:_, :__impl__, :_}]
    ]
  end

  def application, do: []

  def description do
    "Code generation library for functional lenses"
  end

  defp package do
    [
      description: description(),
      licenses: ["BSD-2-Clause"],
      files: [
        "lib",
        "mix.exs",
        "README.md",
        ".formatter.exs"
      ],
      maintainers: [
        "Georgy Sychev"
      ],
      links: %{GitHub: "https://github.com/hissssst/pathex"}
    ]
  end

  defp deps do
    [
      {:mix_unused, "~> 0.3.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false}
    ]
  end

  # Docs section

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extra_section: "GUIDES",
      groups_for_modules: groups_for_modules(),
      extras: ["README.md" | Path.wildcard("guides/*")],
      groups_for_extras: groups_for_extras()
    ]
  end

  defp groups_for_extras do
    [
      Tutorials: ~r/guides\/.*/
    ]
  end

  defp groups_for_modules do
    [
      Public: [
        Pathex,
        Pathex.Lenses
      ],
      "Code generation": [
        Pathex.Builder,
        Pathex.Builder.Code
      ],
      "Operation modes": [
        Pathex.Combination,
        Pathex.Operations,
        Pathex.QuotedParser,
        Pathex.Parser
      ],
      "Viewers generation": [
        Pathex.Builder.Viewer,
        Pathex.Builder.MatchableViewer,
        Pathex.Builder.SimpleViewer
      ],
      "Updaters generation": [
        Pathex.Builder.Setter,
        Pathex.Builder.ForceUpdater,
        Pathex.Builder.SimpleUpdater
      ],
      "Compostitions generation": [
        Pathex.Builder.Composition,
        Pathex.Builder.Composition.And,
        Pathex.Builder.Composition.Or
      ],
      Utilities: [
        Pathex.Common
      ]
    ]
  end
end
