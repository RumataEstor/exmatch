defmodule Exmatch.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :exmatch,
      description: description(),
      version: "0.5.0",
      elixir: "~> 1.10",
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: ["lib"] ++ if(Mix.env() == :test, do: ["test/support"], else: []),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]

  def application,
    do: []

  defp description,
    do: """
    This library is meant to provide an ergonomic way to match, compare and bind data in complex types such as maps and structs.
    """

  defp deps,
    do: [
      {:decimal, "~> 2.0", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test]},
      {:timex, "~> 3.7", only: [:dev, :test]}
    ]

  defp package,
    do: [
      files: ["lib", "mix.exs", ".formatter.exs", "README.md"],
      maintainers: ["Dmitry Belyaev"],
      licenses: ["Apache-2.0"],
      links: %{
        GitHub: "https://github.com/RumataEstor/exmatch"
      }
    ]
end
