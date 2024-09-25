defmodule VenndrSDK.MixProject do
  use Mix.Project

  def project() do
    [
      app: :venndr_sdk,
      version: "0.1.0",
      elixir: "~> 1.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Venndr SDK",
      source_url: "https://github.com/venndr/venndr-elixir-sdk"
    ]
  end

  def application() do
    []
  end

  defp deps() do
    [
      {:plug, "~> 1.16"},
      {:redix, "~> 1.1"},
      {:awesome_ex_crypto, git: "https://github.com/awesome-elixir/awesome_ex_crypto"},
      {:httpoison, "~> 1.8"},
      {:mimic, "~> 1.7", only: :test}
    ]
  end

  defp description() do
    "SDK for interacting with Venndr."
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/venndr/venndr-elixir-sdk"}
    ]
  end
end
