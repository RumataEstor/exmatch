defmodule Exmatch.MixProject do
  use Mix.Project

  def project do
    [
      app: :exmatch,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:decimal, "~> 2.0", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test]},
      {:timex, "~> 3.7", only: [:dev, :test]}
    ]
  end
end
