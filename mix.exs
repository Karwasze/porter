defmodule Porter.MixProject do
  use Mix.Project

  def project do
    [
      app: :porter,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {AudioPlayerSupervisor, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      [{:nostrum, github: "Kraigie/nostrum"}]
    ]
  end
end
