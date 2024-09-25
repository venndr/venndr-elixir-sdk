defmodule VenndrSDK.KeysTest do
  use ExUnit.Case, async: true
  use Mimic

  alias VenndrSDK.Keys

  @key """
  -----BEGIN RSA PUBLIC KEY-----
  MIIBCgKCAQEAnzKquBKihkXANnvanftNv/MG3Zd4tMMj+AByMiLFrBGpiOnDfPuh
  nuKszZhUGN5eC1PEFrzf5QnTK58dY2+/r2PXuZcXz3w+hwk+aC09ryboCD1Cc1ae
  0Sins7p22uQyWSt0cfhun5TdeXhPhFFSQgI7DtA8sUfHE+fsYB4feOsimouNweKE
  /gKb0S7yq1Bno3e1/iBsFrj26ekYOVQQ1tn5dOzmoI5zM5wKAburKZEGL4xOU/mq
  kPL0nUpaxoGT8Vx3zx22yr9Y2O7CIfYGESLHSRcNYh4z2JZrPq8QgptuUAB/wCF/
  vEwI/GwPk8XWswxPwbI/VXrBqtSq4/06jwIDAQAB
  -----END RSA PUBLIC KEY-----
  """

  @key_version "2022-02-14"

  test "uses cached value when availale" do
    expect(Redix, :command, fn _, _ -> {:ok, @key} end)
    reject(&HTTPoison.get/3)

    {:ok, %ExPublicKey.RSAPublicKey{}} = Keys.pubkey(@key_version)
  end

  test "fetches from remote when cache is empty" do
    Redix
    |> stub(:command, fn _, _ -> {:ok, nil} end)
    |> expect(:command, fn _, _ -> {:ok, nil} end)

    expect(HTTPoison, :get, fn _, _, _ -> {:ok, %{body: @key, status_code: 200}} end)

    {:ok, %ExPublicKey.RSAPublicKey{}} = Keys.pubkey(@key_version)
  end

  test "fetches from remote when cache returns error" do
    Redix
    |> stub(:command, fn _, _ -> {:ok, nil} end)
    |> expect(:command, fn _, _ -> {:error, "redis is much sad"} end)

    expect(HTTPoison, :get, fn _, _, _ -> {:ok, %{body: @key, status_code: 200}} end)

    {:ok, %ExPublicKey.RSAPublicKey{}} = Keys.pubkey(@key_version)
  end

  # this test relies on implementation details, which isn't ideal, but it's necessary because the
  # client uses the Redix library directly. a more robust implementation would provide an
  # abstracted storage adapter (or repo), which would enable testing without using internals.
  test "updates cache on successful fetch from remote" do
    Redix
    |> expect(:command, fn :pubkey_cache_redix, ["GET", @key_version] -> {:ok, nil} end)
    |> expect(:command, fn :pubkey_cache_redix, ["SET", @key_version, @key, "NX"] ->
      {:ok, nil}
    end)

    expect(HTTPoison, :get, fn _, _, _ -> {:ok, %{body: @key, status_code: 200}} end)

    {:ok, %ExPublicKey.RSAPublicKey{}} = Keys.pubkey(@key_version)
  end

  test "error is returnd and cache update is skipped on remote fetch failure" do
    expect(Redix, :command, fn :pubkey_cache_redix, ["GET", @key_version] -> {:ok, nil} end)
    reject(&Redix.command/2)
    expect(HTTPoison, :get, fn _, _, _ -> {:ok, %{body: @key, status_code: 404}} end)

    {:error, :load_failed} = Keys.pubkey(@key_version)
  end
end
