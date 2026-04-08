defmodule AHCIP.MixProject do
  use Mix.Project

  def project do
    [
      app: :ahcip,
      version: "0.1.0",
      elixir: "~> 1.19",
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
      {:kodon, git: "https://github.com/pletcher/kodon_ex.git", ref: "ddc663cfad91ceb194cca5d339de57969698198a"}
    ]
  end
end
