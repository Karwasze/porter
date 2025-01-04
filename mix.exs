defmodule Porter.MixProject do
  use Mix.Project

  def project do
    [
      app: :porter,
      version: "0.1.0",
      elixir: ">= 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {MyApp.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nostrum, github: "BrandtHill/nostrum", branch: "master"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
