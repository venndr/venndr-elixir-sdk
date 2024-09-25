defmodule VenndrSDK.Plug.VerifyEmbedSignature do
  @moduledoc """
  Verifies the signature of an embed request

  Options:
  max_age  - the maximum age for a signed URL in seconds (default: 600)
  """

  import Plug.Conn

  alias Plug.Conn
  alias VenndrSDK.Keys

  @behaviour Plug

  defmodule InvalidSignatureError do
    message = "signature validation failed"
    defexception message: message, plug_status: 400
  end

  defmodule KeyFetchError do
    message = "unable to load public key"
    defexception message: message, plug_status: 500
  end

  defmodule MaxAgeExceededError do
    message = "request is too old"
    defexception message: message, plug_status: 400
  end

  @default_max_sigv_age 600

  @impl true
  def init(opts \\ []), do: Keyword.put_new(opts, :max_age, @default_max_sigv_age)

  @impl true
  def call(conn, opts \\ []) do
    max_age = Keyword.get(opts, :max_age)

    case conn |> validate_age(max_age) |> validate_signature(reconstruct_url(conn)) do
      :ok -> conn
      {:error, :max_age_exceeded} -> raise MaxAgeExceededError
      {:error, :unable_to_load_key} -> raise KeyFetchError
      _ -> raise InvalidSignatureError
    end
  end

  @spec validate_age(Conn.t(), integer()) ::
          Conn.t() | {:error, :max_age_exceeded | :invalid_sigt}
  defp validate_age(conn, max_age),
    do:
      conn
      |> fetch_query_params()
      |> get_sigt()
      |> then(fn
        {:error, _} = err ->
          err

        sigt ->
          case DateTime.to_unix(DateTime.utc_now()) - sigt do
            diff when diff < 0 ->
              {:error, :invalid_sigt}

            diff when diff > max_age ->
              {:error, :max_age_exceeded}

            _ ->
              conn
          end
      end)

  # pluck sigt from the query_params map
  @spec get_sigt(Conn.t()) :: integer() | {:error, :invalid_sigt}
  defp get_sigt(conn),
    do:
      conn.query_params
      |> Map.get("sigt", "0")
      |> Integer.parse()
      |> (case do
            {sigt, _} -> sigt
            :error -> {:error, :invalid_sigt}
          end)

  @spec reconstruct_url(conn :: Conn.t()) :: String.t()
  defp reconstruct_url(conn),
    do: "#{scheme(conn)}://#{host(conn)}#{conn.request_path}?#{conn.query_string}"

  @spec scheme(Conn.t()) :: String.t()
  defp scheme(%{req_headers: headers} = conn),
    do:
      Enum.find_value(headers, conn.scheme, fn
        {"x-forwarded-proto", scheme} -> scheme
        _ -> nil
      end)

  @spec host(Conn.t()) :: String.t()
  defp host(%{req_headers: headers} = conn) do
    hmap = Enum.into(headers, %{})

    # prefer the x-forwarded-host and host headers, in that order, as they will have the full host
    # (with port when applicable). when neither is available, we make a best effort reconstruction
    case {Map.get(hmap, "x-forwarded-host"), Map.get(hmap, "host")} do
      {nil, nil} -> host(conn.scheme, conn.port, conn.host)
      {fh, _} when not is_nil(fh) -> fh
      {_, h} when not is_nil(h) -> h
    end
  end

  @spec host(scheme :: :http | :https, port :: :inet.port_number(), host :: String.t()) ::
          String.t()
  defp host(:https, 443, host), do: host
  defp host(:http, 80, host), do: host
  defp host(_, port, host), do: "#{host}:#{port}"

  @spec validate_signature({:error, t}, any()) :: {:error, t} when t: any()
  defp validate_signature({:error, _} = err, _), do: err

  @spec validate_signature(conn :: Conn.t(), url :: binary()) ::
          :ok | {:error, :invalid_signature | any()}
  defp validate_signature(conn, url) do
    with {message, sig} <- extract_message_and_sig(url),
         {:ok, hash} <- Base.url_decode64(sig, padding: false),
         {:ok, key} <-
           conn
           |> fetch_query_params()
           |> get_sigv()
           |> Keys.pubkey(),
         {:ok, true} <- ExPublicKey.verify(message, hash, key) do
      :ok
    else
      {:error, :load_failed} -> {:error, :unable_to_load_key}
      _ -> {:error, :invalid_signature}
    end
  end

  # pluck sigv from the query_params map
  @spec get_sigv(Conn.t()) :: binary() | {:error, :signature_not_found}
  defp get_sigv(conn),
    do:
      conn.query_params
      |> Map.get("sigv")
      |> (case do
            nil -> {:error, :signature_not_found}
            sigv -> sigv
          end)

  @spec extract_message_and_sig(url :: String.t()) :: {binary(), binary()}
  defp extract_message_and_sig(signed_url) do
    # reverse the URL and find the first ampersand (&), which is the split point
    clist = signed_url |> to_charlist() |> Enum.reverse()
    split = Enum.find_index(clist, fn c -> [c] == ~c"&" end)

    # the sig is everything to the left of the split point, omitting "=gis&"
    sig =
      clist
      |> Enum.slice(0..(split - 5))
      |> Enum.reverse()
      |> to_string()

    # everything to the right of the split point is the message
    message =
      clist
      |> Enum.slice((split + 1)..-1//1)
      |> Enum.reverse()
      |> to_string()

    {message, sig}
  end
end
