defmodule Liquex.MixProject do
  use Mix.Project

  def project do
    [
      app: :liquex,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 0.5.3"},
      {:timex, "~> 3.6.1"},
      {:html_entities, "~> 0.5.1"},
      {:html_sanitize_ex, "~> 1.3.0-rc3"}
    ]
  end
end
