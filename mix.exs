defmodule Ex4j.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4j,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ex4j.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bolt_sips, "~> 2.0"},
      {:ecto, "~> 3.10"},
      {:json, "~> 1.4", override: true}
    ]
  end
end
