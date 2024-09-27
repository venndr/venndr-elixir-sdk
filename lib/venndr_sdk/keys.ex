defmodule VenndrSDK.Keys do
  @redix_instance :pubkey_cache_redix

  @doc """
  pubkey/1 fetches a Venndr public key and caches it for future use.
  """
  @spec pubkey(version :: binary()) ::
          {:ok, ExPublicKey.RSAPublicKey.t()}
          | {:error, :missing_key_version | :load_failed}
  def pubkey(nil), do: {:error, :missing_key_version}

  @doc false
  def pubkey(version),
    do:
      version
      |> load_key()
      |> then(fn
        {:ok, key} -> ExPublicKey.loads(key)
        _ -> {:error, :load_failed}
      end)

  defp load_key(version),
    do:
      @redix_instance
      |> Redix.command(["GET", version])
      |> then(fn
        {:ok, key} when not is_nil(key) -> {:ok, key}
        _ -> version |> fetch_key() |> update_key_cache(version)
      end)

  defp fetch_key(version) do
    hackney_options = Application.get_env(:venndr_sdk, :hackney_options, [])
    base_url = Application.get_env(:venndr_sdk, :venndr_keys_base_url)

    case HTTPoison.get("#{base_url}/#{version}", [], hackney: hackney_options) do
      {:ok, %{body: body, status_code: 200}} ->
        {:ok, body}

      _ ->
        {:error, :unable_to_load_key}
    end
  end

  defp update_key_cache({:ok, key}, version) do
    Redix.command(@redix_instance, ["SET", version, key, "NX"])

    {:ok, key}
  end

  defp update_key_cache(v, _), do: v
end
