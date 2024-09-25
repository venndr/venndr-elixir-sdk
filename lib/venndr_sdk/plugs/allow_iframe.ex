defmodule VenndrSDK.Plug.AllowIframe do
  @moduledoc """
  Allows affected resources to be open in iframe.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts \\ %{}), do: Enum.into(opts, %{})

  @impl true
  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", "frame-ancestors *")
    |> delete_resp_header("x-frame-options")
  end
end
