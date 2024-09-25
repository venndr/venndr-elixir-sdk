defmodule VenndrSDK.CacheBodyReader do
  @moduledoc """
  In Phoenix it is common practice to parse the body response very early in the connection pipeline.
  This is normally fine, but since we need the raw body for webhook verification, we use this module
  to cache the request body for later use.

  See more: https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader
  """

  @doc false
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
