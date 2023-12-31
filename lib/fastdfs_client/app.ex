defmodule FastdfsClient.App do

  use Application

  def start(_type, _args) do
    stracker  = Application.get_all_env(:fastdfs_client)
    case Keyword.fetch(stracker, :fdfs_server) do
      {:ok, endpoints} ->
        children = [
          FastdfsClient.Registry,
          Supervisor.child_spec(
            {FastdfsClient.Pool, endpoints},
            id: FastdfsClient.Pool.Supervisor
          )
        ]

        Supervisor.start_link(children, strategy: :one_for_all, name: __MODULE__)

      :error ->
        raise ArgumentError, "expected :endpoints or :host in the config file(config.exs)"
    end
  end

end
