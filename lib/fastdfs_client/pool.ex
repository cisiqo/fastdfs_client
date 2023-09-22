defmodule FastdfsClient.Pool do

  @default_port 22122
  @default_pool_size 2

  use Supervisor, restart: :temporary

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    case FastdfsClient.Registry.start_link() do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
    endpoints = parse_endpoints(args)
    children = make_childrens(endpoints, args, [])
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp conn(args) do
    child_opts = [id: make_ref(), shutdown: 10_000]
    FastdfsClient.Connection.child_spec(args, child_opts)
  end

  defp make_childrens([], _size, children) do
    children
  end

  defp make_childrens([{host, port} | remaining_endpoints], args, children) do
    size = Keyword.get(args, :pool_size, @default_pool_size)
    args = Keyword.merge([host: host, port: port], args)
    new_children = for _id <- 1..size, do: conn(args)
    make_childrens(remaining_endpoints, args, children ++ new_children)
  end

  defp parse_endpoints(opts) do
    case Keyword.fetch(opts, :endpoints) do
      {:ok, endpoints} when is_list(endpoints) ->
        Enum.map(endpoints, fn
          {host} ->
            port = Keyword.get(opts, :port, @default_port)
            {to_charlist(host), port}

          {host, port} -> {host, port}
        end)

      {:ok, _} ->
        raise ArgumentError, "expected :endpoints to be a list of tuples"

      :error ->
        port = Keyword.get(opts, :port, @default_port)
        case Keyword.fetch(opts, :host) do
          {:ok, host} ->
            [{host, port}]

          :error ->
            raise ArgumentError,
                  "expected :host, endpoints to be given"
        end
    end
  end

end
