defmodule Pathex.MixProject do
  use Mix.Project

  @version "2.6.0"

  def project do
    [
      app: :pathex,
      version: @version,
      elixir: ">= 1.13.0 and < 1.17.0 or > 1.18.0 or == 1.18.0-dev",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Pathex",
      source_url: "https://github.com/hissssst/pathex",
      docs: docs()

      # compilers: [:unused | Mix.compilers()],
      # unused: [{:_, :__using__, :_}, {:_, :__impl__, :_}]
    ]
  end

  def application, do: []

  def description do
    "Functional lenses for nested structures"
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
      links: %{
        GitHub: "https://github.com/hissssst/pathex",
        Changelog: "https://github.com/hissssst/pathex/blob/master/CHANGELOG.md"
      }
    ]
  end

  defp deps do
    [
      # # Uncomment for development
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:mix_unused, "~> 0.3", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
    ]
  end

  # Docs section

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extra_section: "GUIDES",
      groups_for_modules: groups_for_modules(),
      extras: ["README.md" | Path.wildcard("guides/*/*")] ++ ["CHANGELOG.md"],
      groups_for_extras: groups_for_extras()
    ]
  end

  defp groups_for_extras do
    [
      Tutorials: ~r/guides\/tutorials\/.*/
    ]
  end

  defp groups_for_modules do
    [
      Public: [
        Pathex,
        Pathex.Lenses,
        Pathex.Lenses.Recur,
        Pathex.Combinator,
        Pathex.Debug,
        Pathex.Accessibility,
        Pathex.Short
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
        Pathex.Builder.SimpleUpdater,
        Pathex.Builder.SimpleDeleter
      ],
      "Compostitions generation": [
        Pathex.Builder.Composition,
        Pathex.Builder.Composition.And,
        Pathex.Builder.Composition.Concat,
        Pathex.Builder.Composition.Or
      ],
      "Deletion generation": [
        Pathex.Builder.SimpleDeleter
      ],
      "Inspection generation": [
        Pathex.Builder.Inspector
      ],
      Lenses: [
        Pathex.Lenses.All,
        Pathex.Lenses.Any,
        Pathex.Lenses.Filtering,
        Pathex.Lenses.Matching,
        Pathex.Lenses.Recur,
        Pathex.Lenses.Some,
        Pathex.Lenses.Star
      ],
      Utilities: [
        Pathex.Common
      ]
    ]
  end
end
