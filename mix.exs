defmodule FastdfsClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :fastdfs_client,
      version: "0.3.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {FastdfsClient.App, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:connection, "~> 1.1"},
      {:backoff, "~> 1.1.6"},
    ]
  end

  defp description() do
    "A fastdfs client library."
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "fastdfs_client",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README*  LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cisiqo/fastdfs_client"}
    ]
  end

end
