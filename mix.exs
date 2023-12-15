defmodule Ex4j.MixProject do
  use Mix.Project

  @version "0.1.0"
  @url_docs "https://hexdocs.pm/ex4j."
  @url_github "https://github.com/tiagodavi/ex4j"

  def project do
    [
      app: :ex4j,
      name: "Ex4j",
      source_url: @url_github,
      homepage_url: @url_docs,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: @url_github
    ]
  end

  defp description do
    "Combine the power of Ecto with the Bolt protocol + an elegant DSL for Neo4J databases."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      maintainers: [
        "Tiago D S Batista"
      ],
      links: %{
        "Docs" => @url_docs,
        "Github" => @url_github
      }
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @url_github,
      main: "Ex4j",
      extra_section: "guides",
      extras: ["README.md", "NOTICE", "LICENSE"]
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
