defmodule Lomekwi.MixProject do
  use Mix.Project

  def project do
    [
      app: :lomekwi,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: CoverModule],
      deps: deps(),
      name: "Lomekwi",
      source_url: "https://github.com/jppianta/Lomekwi",
      docs: [
        # The main page in the docs
        main: "Lomekwi",
        logo: "assets/lomekwi_no_name.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :cowboy, :plug, :jason]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_crypto, "~> 0.10.0"},
      {:plug_cowboy, "~> 2.0"},
      {:plug, "~> 1.8"},
      {:jason, "~> 1.1"},
      {:poison, "~> 4.0"},
      {:httpoison, "~> 1.5"},
      {:logger_file_backend, "~> 0.0.10"},
      {:progress_bar, "~> 2.0"},
      {:binary, "~> 0.0.5"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end
