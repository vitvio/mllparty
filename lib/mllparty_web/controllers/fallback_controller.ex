defmodule MLLPartyWeb.FallbackController do
  use MLLPartyWeb, :controller
  require Logger

  def call(conn, :ok) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(:no_content, "")
  end

  def call(conn, {:error, :invalid_request}) do
    call(conn, {:error, :invalid_request, "Invalid request"})
  end

  def call(conn, {:error, :invalid_request, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: message})
  end

  def call(conn, {:error, :unauthorized}) do
    Logger.info("Unauthorized")

    conn
    |> put_status(:unauthorized)
    |> json(%{message: "Unauthorized"})
  end
end
