defmodule VenndrSDK.Plug.VerifyEmbedSignatureTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  alias VenndrSDK.Keys
  alias VenndrSDK.Plug.VerifyEmbedSignature.{InvalidSignatureError, MaxAgeExceededError}

  @test_key """
  -----BEGIN RSA PUBLIC KEY-----
  MIIBCgKCAQEAnzKquBKihkXANnvanftNv/MG3Zd4tMMj+AByMiLFrBGpiOnDfPuh
  nuKszZhUGN5eC1PEFrzf5QnTK58dY2+/r2PXuZcXz3w+hwk+aC09ryboCD1Cc1ae
  0Sins7p22uQyWSt0cfhun5TdeXhPhFFSQgI7DtA8sUfHE+fsYB4feOsimouNweKE
  /gKb0S7yq1Bno3e1/iBsFrj26ekYOVQQ1tn5dOzmoI5zM5wKAburKZEGL4xOU/mq
  kPL0nUpaxoGT8Vx3zx22yr9Y2O7CIfYGESLHSRcNYh4z2JZrPq8QgptuUAB/wCF/
  vEwI/GwPk8XWswxPwbI/VXrBqtSq4/06jwIDAQAB
  -----END RSA PUBLIC KEY-----
  """

  # 2024-09-01 12:34:56Z
  @mock_time DateTime.from_unix!(1_725_194_096)

  setup do
    valid_path =
      "https://example.com/embed?sigt=1725194096&sigv=2022-02-14&sig=IlRk9NgyytUUSDaEnQ_7zJYfWZi6hJAskjTzwGJ-PVWcMUIA-7XotshTqIq-Vt8b896O4umVEhcBnoRKVW9rDS-qkL5Aatc40PT012_TgEv7IPijfA3M9nz69Bjf37RIUkVwGD46CNpXcNkR2MTclx9zjeMFaeMtLtYQDG7Vua_F1Usnasj4rbPdALEpeMqA3Bmf_yvjRSBdMFoJckQ9lZ-YvLUSikI46zVpSwmyHCF0xjWMI9JgUdIpDG1yS75OKtYHSQnYd8KMqa5JJAiNj9SWehgVq2n-cZi0OGzcklil4GfcdKo13_GOyFv10NRfM2T0NSnIOomIcpf8ukweFQ"

    doctored_path =
      "https://example.com/embed?sigt=1725454286&sigv=2022-02-14&sig=IlRk9NgyytUUSDaEnQ_7zJYfWZi6hJAskjTzwGJ-PVWcMUIA-7XotshTqIq-Vt8b896O4umVEhcBnoRKVW9rDS-qkL5Aatc40PT012_TgEv7IPijfA3M9nz69Bjf37RIUkVwGD46CNpXcNkR2MTclx9zjeMFaeMtLtYQDG7Vua_F1Usnasj4rbPdALEpeMqA3Bmf_yvjRSBdMFoJckQ9lZ-YvLUSikI46zVpSwmyHCF0xjWMI9JgUdIpDG1yS75OKtYHSQnYd8KMqa5JJAiNj9SWehgVq2n-cZi0OGzcklil4GfcdKo13_GOyFv10NRfM2T0NSnIOomIcpf8ukweFQ"

    missing_sigt =
      "https://example.com/embed?sigv=2022-02-14&sig=IlRk9NgyytUUSDaEnQ_7zJYfWZi6hJAskjTzwGJ-PVWcMUIA-7XotshTqIq-Vt8b896O4umVEhcBnoRKVW9rDS-qkL5Aatc40PT012_TgEv7IPijfA3M9nz69Bjf37RIUkVwGD46CNpXcNkR2MTclx9zjeMFaeMtLtYQDG7Vua_F1Usnasj4rbPdALEpeMqA3Bmf_yvjRSBdMFoJckQ9lZ-YvLUSikI46zVpSwmyHCF0xjWMI9JgUdIpDG1yS75OKtYHSQnYd8KMqa5JJAiNj9SWehgVq2n-cZi0OGzcklil4GfcdKo13_GOyFv10NRfM2T0NSnIOomIcpf8ukweFQ"

    missing_sigv =
      "https://example.com/embed?sigt=1725194096&sig=IlRk9NgyytUUSDaEnQ_7zJYfWZi6hJAskjTzwGJ-PVWcMUIA-7XotshTqIq-Vt8b896O4umVEhcBnoRKVW9rDS-qkL5Aatc40PT012_TgEv7IPijfA3M9nz69Bjf37RIUkVwGD46CNpXcNkR2MTclx9zjeMFaeMtLtYQDG7Vua_F1Usnasj4rbPdALEpeMqA3Bmf_yvjRSBdMFoJckQ9lZ-YvLUSikI46zVpSwmyHCF0xjWMI9JgUdIpDG1yS75OKtYHSQnYd8KMqa5JJAiNj9SWehgVq2n-cZi0OGzcklil4GfcdKo13_GOyFv10NRfM2T0NSnIOomIcpf8ukweFQ"

    missing_sig =
      "https://example.com/embed?sigt=1725194096&sigv=2022-02-14"

    partial_sig =
      "https://example.com/embed?sigt=1725194096&sigv=2022-02-14&sig=IlRk9NgyytUUSDaEnQ_7zJYfWZi6hJAskjTzwGJ-PVWcMUIA-7XotshTqIq-Vt8b896O4umVEhcBnoRKVW9rDS-qkL5Aatc40PT012_TgEv7IPijfA3M9nz69Bjf37RIUkVwGD46CNpXcNkR2MTclx9zjeMFaeMtLtYQDG7Vua_F1Usnasj4rbPdALEpeMqA3Bmf_yvjRSBdMFoJckQ9lZ-YvLUSikI46zVpSwmyHCF0xjWMI9JgUdIpDG1yS75OKtYHSQnYd8KMqa5JJAiNj9SWehgVq2n"

    # timestamp is @mock_time-86400 seconds
    expired_signature =
      "https://example.com/embed?sigt=1725107696&sigv=2022-02-14&sig=BH8wMfrWc3K1iIuH7D19Hc8k_AIYHw0bCindjmzFs227Ho_9tklM9zSSljR4BCnV5VMzKxcEyHFj8vF0NjuOvcDlp3rEyROhzntg_5t2vrpX7rtivOUwGBjLzejQoJA1lc2lpkUkVkV45gojoWL4WylEXqzzy4VoZhYFWlARr0IAQfnM2SDaj7Ui3_0WXc2gGtgmttsS81MHw85v2DQ8_JenaSNPA3g0u0UsqEx7cLs3YjkryisA912WqFrMHR6Q2iF0mmImbWuBT_qLRf5sjUI_3Ityu3AHi7SyC8xR4FsKpnQLgla1dAzAV5uDD53d0Tl8oAmu0BR-SjI-oUY_kQ"

    default_opts = VenndrSDK.Plug.VerifyEmbedSignature.init()

    stub(Keys, :pubkey, fn
      "2022-02-14" -> ExPublicKey.loads(@test_key)
      _ -> {:error, :unexpected_key_version}
    end)

    stub(DateTime, :utc_now, fn -> @mock_time end)

    {:ok,
     %{
       default_opts: default_opts,
       invalid_paths: [doctored_path, missing_sigv, missing_sig, partial_sig],
       expired_signatures: [missing_sigt, expired_signature],
       valid_path: valid_path
     }}
  end

  test "valid embeds pass", %{valid_path: valid, default_opts: opts} do
    assert VenndrSDK.Plug.VerifyEmbedSignature.call(conn(:get, valid), opts)
  end

  test "invalid embeds are failed", %{invalid_paths: invalids, default_opts: opts} do
    Enum.each(invalids, fn invalid ->
      assert_raise(InvalidSignatureError, fn ->
        VenndrSDK.Plug.VerifyEmbedSignature.call(conn(:get, invalid), opts)
      end)
    end)
  end

  test "expired signatures are rejected", %{expired_signatures: expireds, default_opts: opts} do
    Enum.each(expireds, fn expired ->
      assert_raise(MaxAgeExceededError, fn ->
        VenndrSDK.Plug.VerifyEmbedSignature.call(conn(:get, expired), opts)
      end)
    end)
  end

  test "valid embeds pass for forwarded requests", %{valid_path: valid, default_opts: opts} do
    %{host: orig_host, scheme: orig_scheme} = orig_url = URI.parse(valid)

    altered = URI.to_string(%{orig_url | host: "other.example.com", port: 1234, scheme: "http"})

    assert %Plug.Conn{} =
             VenndrSDK.Plug.VerifyEmbedSignature.call(
               conn(:get, altered)
               |> put_req_header("x-forwarded-proto", orig_scheme)
               |> put_req_header("x-forwarded-host", orig_host),
               opts
             )
  end
end
