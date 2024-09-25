defmodule VenndrSDK.Plug.WebhookVerifierTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  alias VenndrSDK.Keys
  alias VenndrSDK.Plug.WebhookVerifier

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

  @test_payload [
    "{\"action\":\"testing\",\"payload\":{\"created_at\":\"2023-07-11T12:41:18.671870Z\",\"message\":\"Testing 1..2..3! Beep boop, bleep bloop!\"},\"platform_id\":\"5020e8a0-3266-4b7c-8a90-f0ce2f5c1087\",\"request_id\":\"b2bd8273-8991-4d6a-b625-88af91d2d04d\",\"store_id\":\"a5902e6b-5513-4603-b5ba-d0504d890db7\",\"topic\":\"testing\",\"version\":\"1\"}"
  ]

  @test_headers """
                Venndr-Id: b2bd8273-8991-4d6a-b625-88af91d2d04d
                Venndr-Platform-Handle: platform
                Venndr-Platform-Id: 5020e8a0-3266-4b7c-8a90-f0ce2f5c1087
                Venndr-Store-Handle: store
                Venndr-Store-Id: a5902e6b-5513-4603-b5ba-d0504d890db7
                Venndr-Topic: testing
                Venndr-Version: 1
                Venndr-Key-Version: testing
                Venndr-Signature: l2YqsY6wo689LgUG7uwSI3Jzseqkso7LyWlDZEdGg6Dc+2p0d32/OXT1VHhsmWuIhIIh7+OvU/0zT5VD2RDsO4PNLLFmhul+OiVa1v0/jWbWEeJDqm0vOdfVGyqLETLecSBtDhO7gziwUSrJsLnptoyvxgvhmCzuV9fBp0ObP0ekA6CN1Uxn33kIhPM7iETFRbEpi8uA1drsF0vcMDjz4b6tSROzhtcp2aY/AfpqbbiVJJZ4sjwPamIJNa2RMzOsdBzt8RYwmrabd6NNfvtf3GGdL/gc0vkKAZSuRwjQBDPKq/arzb0s0q4/kNIVg/tUcg++dsOqd3XtxYHbNLPI8g==
                Venndr-Timestamp: 1689079288
                """
                |> String.split("\n")
                |> Enum.filter(fn
                  "" -> false
                  _ -> true
                end)
                |> Enum.map(fn s -> String.split(s, ": ", parts: 2) end)
                |> Enum.map(fn [key, value] ->
                  {key |> String.downcase() |> String.trim(), String.trim(value)}
                end)

  setup do
    stub(Keys, :pubkey, fn _ -> ExPublicKey.loads(@key) end)
    {:ok, %{conn: conn(:post, "/webhooks", %{})}}
  end

  test "passes for valid payloads", %{conn: conn} do
    conn
    |> merge_req_headers(@test_headers)
    |> assign(:raw_body, @test_payload)
    |> WebhookVerifier.call(nil)
    |> assert()
  end

  test "fails empty payloads", %{conn: conn} do
    assert_raise WebhookVerifier.EmptyPayloadError, fn ->
      conn
      |> merge_req_headers(@test_headers)
      |> assign(:raw_body, [])
      |> WebhookVerifier.call(nil)
    end
  end

  test "fails invalid payloads", %{conn: conn} do
    assert_raise WebhookVerifier.InvalidSignatureError, fn ->
      conn
      |> merge_req_headers(@test_headers)
      |> assign(:raw_body, ["beep boop"])
      |> WebhookVerifier.call(nil)
    end
  end

  test "fails requests without venndr key version", %{conn: conn} do
    without_key = Enum.filter(@test_headers, fn {header, _} -> header != "venndr-key-version" end)

    assert_raise WebhookVerifier.MissingVenndrKeyVersionError, fn ->
      conn
      |> merge_req_headers(without_key)
      |> assign(:raw_body, ["beep boop"])
      |> WebhookVerifier.call(nil)
    end
  end
end
