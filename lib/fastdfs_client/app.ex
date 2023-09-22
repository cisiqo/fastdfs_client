defmodule FastdfsClient.App do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      dynamic_supervisor(FastdfsClient.Pool.Supervisor),
    ]

    Supervisor.start_link(children, strategy: :one_for_all, name: __MODULE__)
  end

  defp dynamic_supervisor(name) do
    Supervisor.child_spec(
      {DynamicSupervisor, name: name, strategy: :one_for_one},
      id: name
    )
  end
end
