defmodule VenndrSDK.Plug.InstallVerifierTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  alias VenndrSDK.Keys
  alias VenndrSDK.Plug.InstallVerifier

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
    ~s[{"api_token":"SFMyNTY.g2gDbQAAACQ4ZjMxODQ4MC1mOTY1LTRhNWYtYjUwYi05ZTcxY2Y3NTBmN2NuBgA4X8f1mAFiAAFRgA.pxABVzYKfyv3UIygERf9i-IWeRRjVzcqKGyFKSqDopQ","store_id":"a9da1df7-03c4-4e71-add4-1f3846b7d527"}]
  ]
  @test_headers """
                venndr-id: d94fd13f-59f2-4490-96c4-1146c54c8f78
                venndr-key-version: 2022-02-14
                venndr-signature: K0PeQrKFDaKdG1V/pawTd4wbEK0IzLFrtfFHhGjv2EopIO2lom0KLVlFqVs8LZdntlDyOYDEJ6CriSFj4HIivLZl9dkn1OcbGr7V412Mp3ohYfKclnckJDJ3jcBj3ZZUVDG0kQ/OPPT4QN7o8CuyxwJDC2Jv/WJLkTtJ+ZrSgM9iJDWREU0CKHHawEZGbgHbnByGbCC/fgh528SDdqficqfdoRvgjt44MZnugyWuNym3xeE2V7CEW2L7Ty52NbnckxR5JJMt6FZxtP8YbDsmIGSbJbp5Twx+NZ4a+TV/nvoZrTV17ZDULDDXZiXlM80qcIInQ047s2E+54SQkIfmpA==
                venndr-timestamp: 1756467255
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
    |> InstallVerifier.call(nil)
    |> assert()
  end

  test "fails empty payloads", %{conn: conn} do
    assert_raise InstallVerifier.EmptyPayloadError, fn ->
      conn
      |> merge_req_headers(@test_headers)
      |> assign(:raw_body, [])
      |> InstallVerifier.call(nil)
    end
  end

  test "fails invalid payloads", %{conn: conn} do
    assert_raise InstallVerifier.InvalidSignatureError, fn ->
      conn
      |> merge_req_headers(@test_headers)
      |> assign(:raw_body, ["beep boop"])
      |> InstallVerifier.call(nil)
    end
  end

  test "fails requests without venndr key version", %{conn: conn} do
    without_key = Enum.filter(@test_headers, fn {header, _} -> header != "venndr-key-version" end)

    assert_raise InstallVerifier.MissingVenndrKeyVersionError, fn ->
      conn
      |> merge_req_headers(without_key)
      |> assign(:raw_body, ["beep boop"])
      |> InstallVerifier.call(nil)
    end
  end
end
