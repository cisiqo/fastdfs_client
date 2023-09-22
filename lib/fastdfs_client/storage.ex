defmodule FastdfsClient.Storage do

  alias FastdfsClient.Connection, as: Conn

  def connect(ip_addr, port) do
    params = %Conn{host: ip_addr, port: port, socket_opts: [], timeout: 10_000}
    case FastdfsClient.Protocol.connect(params) do
      {:ok, conn} ->
        {:ok, conn}

      {:error, _} = error ->
        error
    end
  end

end
