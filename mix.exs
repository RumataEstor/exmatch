defmodule Exmatch.MixProject do
  use Mix.Project

  def project do
    check_version!(
      app: :exmatch,
      description: description(),
      version: "0.15.0",
      elixir: "~> 1.10",
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: ["lib"] ++ if(Mix.env() in [:test], do: ["test/support"], else: []),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    )
  end

  def application,
    do: []

  defp description,
    do: """
    This library is meant to provide an ergonomic way to match, compare and bind data in complex types such as maps and structs.
    """

  defp deps,
    do: [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
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

  defp docs,
    do: [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE"
      ]
    ]

  defp check_version!(project) do
    project_version = project[:version]
    readme = File.read!("README.md")
    regex = ~r/defp deps do\s*\[\s*\{:exmatch, "~> ([\d\.]*)",/

    readme_version =
      case Regex.run(regex, readme) do
        [_, readme_version] -> readme_version
        _ -> raise "README.md doesn't contain expected deps example"
      end

    if project_version != readme_version do
      raise "README.md uses #{readme_version} while project uses #{project_version}"
    end

    project
  end
end
