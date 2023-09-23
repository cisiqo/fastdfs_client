defmodule FastdfsClient.Connection do

  @timeout 5_000
  @connect_retry_backoff_default 5_000
  @connect_retry_backoff_max 300_000
  @default_transport FastdfsClient.Protocol

  defstruct host: nil,
            owner: nil,
            port: nil,
            socket: nil,
            socket_opts: [],
            timeout: nil,
            connect_retry_backoff: @connect_retry_backoff_default,
            transport: nil

  use Connection
  require Logger

  def start_link(args) do
    args =
      args
      |> Keyword.put_new(:timeout, @timeout)
      |> Keyword.put_new(:transport, @default_transport)
      |> Keyword.put_new(:owner, self())

      Connection.start_link(__MODULE__, {struct(__MODULE__, args), self()})
  end

  def child_spec(args, child_opts) do
    Supervisor.child_spec(
      %{id: __MODULE__, start: {__MODULE__, :start_link, [args]}},
      child_opts
    )
  end

  @spec close(pid, Keyword.t()) :: :ok
  def close(pid, opts \\ []) do
    Connection.call(pid, :close, opts[:timeout] || @timeout)
  end

  ## Connection callbacks

  def init({conn, caller}) do
    if conn.owner != caller do
      Process.monitor(conn.owner)
    end

    {:connect, :init, conn}
  end

  def connect(_, %{transport: transport, connect_retry_backoff: connect_retry_backoff} = conn) do
    case transport.connect(conn) do
      {:ok, conn} ->
        transport.active_test(conn)
        FastdfsClient.Registry.checkin(conn)
        {:ok, conn}

      {:error, _} = error ->
        connect_retry_backoff =
          :backoff.rand_increment(connect_retry_backoff, @connect_retry_backoff_max)

        Logger.warning(fn ->
          "Connecting failed, retrying in #{connect_retry_backoff} ms.\nFull error: #{
            inspect(error)
          }"
        end)

        {:backoff, connect_retry_backoff, %{conn | connect_retry_backoff: connect_retry_backoff}}
    end
  end

  def disconnect({:close, from}, %{socket: socket, transport: transport} = conn) do
    transport.disconnect({:close, from}, socket)
    {:stop, {:shutdown, :closed}, conn}
  end

  def disconnect({:owner_down, reason}, %{socket: socket, transport: transport} = conn) do
    transport.disconnect({:owner_down, reason}, socket)
    {:stop, {:shutdown, {:owner_down, reason}}, conn}
  end

  def disconnect(info, %{socket: socket, transport: transport} = conn) do
    transport.disconnect(info, socket)
    {:connect, :reconnect, reset_connection(conn)}
  end

  defp reset_connection(conn) do
    %{conn | socket: nil}
  end

  def handle_call(_, _, %{socket: nil} = conn) do
    {:reply, {:error, :closed}, conn}
  end

  def handle_call({:send, data}, _, %{transport: transport} = conn) do
    case transport.send(conn, data) do
      {:ok, conn} ->
        {:reply, :ok, conn}

      {:error, _} = error ->
        {:disconnect, error, error, conn}
    end
  end

  def handle_call(:close, from, %{socket: socket, transport: transport} = conn) do
    transport.disconnect({:close, from}, socket)
    {:reply, :ok, conn}
  end

  def handle_info({:DOWN, _, :process, owner, reason}, %{owner: owner} = conn) do
    {:disconnect, {:owner_down, reason}, conn}
  end

  def handle_info(info, %{transport: transport} = conn) do
    case transport.handle_message(info, conn) do
      {:ok, conn, :more} ->
        {:noreply, conn}

      {:ok, conn, _stanza} ->
        {:noreply, conn}

      {:error, _} = error ->
        {:disconnect, error, conn}

      :unknown ->
        Logger.debug(fn ->
          inspect(__MODULE__) <> inspect(self()) <> " received message: " <> inspect(info)
        end)

        {:noreply, conn}
    end
  end
end
