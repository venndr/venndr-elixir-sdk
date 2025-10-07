defmodule VenndrSDK.Plug.InstallVerifier do
  @moduledoc """
  Verifies incoming un/install payloads using public key/private key RSA.
  """

  import Plug.Conn

  alias VenndrSDK.Keys

  @behaviour Plug

  @message_headers ~w[
    venndr-key-version
    venndr-timestamp
    venndr-id
  ]

  defmodule MissingVenndrKeyVersionError do
    message = "invalid request: missing venndr-key-version"
    defexception message: message, plug_status: 403
  end

  defmodule EmptyPayloadError do
    message = "invalid request: empty payload"
    defexception message: message, plug_status: 403
  end

  defmodule InvalidSignatureError do
    message = "invalid request: signature validation failed"
    defexception message: message, plug_status: 403
  end

  @impl true
  def init(_opts) do
  end

  @impl true
  def call(conn, _opts) do
    skip = is_nil(Application.get_env(:venndr_sdk, :unsafe_skip_install_verify))
    verify(conn, skip)
  end

  defp verify(conn, false), do: conn

  defp verify(%Plug.Conn{} = conn, true) do
    cond do
      missing_key_version?(conn) ->
        raise MissingVenndrKeyVersionError

      empty_payload?(conn) ->
        raise EmptyPayloadError

      not valid_signature?(conn) ->
        raise InvalidSignatureError

      true ->
        conn
    end
  end

  defp missing_key_version?(conn), do: Enum.empty?(get_req_header(conn, "venndr-key-version"))

  defp empty_payload?(%Plug.Conn{assigns: %{raw_body: nil}}), do: true

  defp empty_payload?(%Plug.Conn{assigns: %{raw_body: raw_body}}),
    do: Enum.empty?(raw_body)

  defp valid_signature?(%Plug.Conn{assigns: %{raw_body: [raw_body]}} = conn) do
    [key_version] = get_req_header(conn, "venndr-key-version")
    {:ok, key} = Keys.pubkey(key_version)
    [signature_base64] = get_req_header(conn, "venndr-signature")
    signature = Base.decode64!(signature_base64)

    message =
      raw_body <>
        Enum.reduce(@message_headers, "", fn header, acc ->
          [header_value] = get_req_header(conn, header)
          acc <> header_value
        end)

    {:ok, sig_valid} = ExPublicKey.verify(message, signature, key)

    sig_valid
  end
end
