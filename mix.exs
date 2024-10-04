defmodule VenndrSDK.MixProject do
  use Mix.Project

  def project() do
    [
      app: :venndr_sdk,
      version: "0.1.3",
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
      {:redix, "~> 1.5"},
      {:ex_crypto, "~> 0.10", hex: :ex_crypto_copy},
      {:httpoison, "~> 2.2"},
      {:mimic, "~> 1.7", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "SDK for interacting with Venndr."
  end

  defp package() do
    [
      licenses: ["ISC"],
      links: %{"GitHub" => "https://github.com/venndr/venndr-elixir-sdk"}
    ]
  end
end
