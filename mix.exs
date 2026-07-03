defmodule Neuron.Mixfile do
  use Mix.Project

  @version "5.1.0"
  @github "https://github.com/uesteibar/neuron"

  def project do
    [
      app: :neuron,
      description: "A GraphQL client for elixir.",
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :httpoison]]
  end

  defp deps do
    [
      {:httpoison, "~> 1.0 or ~> 2.0 or ~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:jason, "~> 1.4", optional: true},
      {:mox, "~> 1.1", only: :test},
      {:sham, "~> 1.0", only: :test},
      {:bandit, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE.md"
      ],
      links: %{"github" => @github},
      maintainers: ["Unai Esteibar <uesteibar@gmail.com>"],
      licenses: ["ISC"]
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      assets: "assets",
      source_url: @github,
      source_ref: "v#{@version}",
      logo: "assets/logo.png",
      formatters: ["html"]
    ]
  end

  defp aliases do
    [
      test: "test --cover"
    ]
  end
end
