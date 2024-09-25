# credo:disable-for-this-file ChartReporting.Checks.PublicFunctionsDoc
defmodule VenndrSDK.Plug.WebhookVerifier do
  @moduledoc """
  Verifies incoming webhooks using public key/private key RSA.
  Can optionally be skipped by setting unsafe_skip_webhook_verify (obviously not recommended)
  """

  import Plug.Conn

  alias VenndrSDK.Keys

  @behaviour Plug

  @message_headers [
    "venndr-id",
    "venndr-key-version",
    "venndr-version",
    "venndr-timestamp",
    "venndr-platform-id",
    "venndr-store-id",
    "venndr-topic"
  ]

  defmodule MissingVenndrKeyVersionError do
    message = "invalid webhook: missing venndr-key-version"
    defexception message: message, plug_status: 403
  end

  defmodule EmptyPayloadError do
    message = "invalid webhook: empty payload"
    defexception message: message, plug_status: 403
  end

  defmodule InvalidSignatureError do
    message = "invalid webhook: signature validation failed"
    defexception message: message, plug_status: 403
  end

  @impl true
  def init(_opts) do
  end

  @impl true
  def call(conn, _opts) do
    skip = is_nil(Application.get_env(:chart_reporting, :unsafe_skip_webhook_verify))
    verify(conn, skip)
  end

  defp verify(conn, false), do: conn

  defp verify(%Plug.Conn{} = conn, true) do
    cond do
      missing_key_version?(conn) ->
        raise MissingVenndrKeyVersionError

      empty_payload?(conn) ->
        raise EmptyPayloadError

      invalid_signature?(conn) ->
        raise InvalidSignatureError

      true ->
        conn
    end
  end

  defp missing_key_version?(conn), do: Enum.empty?(get_req_header(conn, "venndr-key-version"))

  defp empty_payload?(%Plug.Conn{assigns: %{raw_body: nil}}), do: true

  defp empty_payload?(%Plug.Conn{assigns: %{raw_body: raw_body}}),
    do: Enum.empty?(raw_body)

  defp invalid_signature?(%Plug.Conn{assigns: %{raw_body: [raw_body]}} = conn) do
    [key_version] = get_req_header(conn, "venndr-key-version")
    {:ok, key} = Keys.pubkey(key_version)
    [signature_base64] = get_req_header(conn, "venndr-signature")
    signature = Base.decode64!(signature_base64)

    message =
      Enum.reduce(@message_headers, "", fn header, acc ->
        [header_value] = get_req_header(conn, header)
        acc <> header_value
      end) <> raw_body

    {:ok, sig_valid} = ExPublicKey.verify(message, signature, key)

    !sig_valid
  end
end
