defmodule FastdfsClient.Registry do

  require Logger
  use GenServer

  def checkout() do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(conn) do
    GenServer.cast(__MODULE__, {:checkin, conn})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    pool = :ets.new(__MODULE__, [:named_table, :bag, read_concurrency: true])
    queue = :queue.new()
    {:ok, {pool, queue}}
  end

  def handle_call(:checkout, _from, {pool, queue}) do
    case :queue.out_r(queue) do
      {:empty, _} ->
          case :ets.match_object(pool, :"$1") do
            [] ->
              {:reply, [], {pool, queue}}

            all ->
              queue = :queue.from_list(all)
              {{:value, item}, queue1} = :queue.out_r(queue)
              {:reply, item, {pool, queue1}}
          end

      {{:value, item}, queue1} ->
        {:reply, item, {pool, queue1}}
    end
  end

  def handle_cast({:checkin, conn}, {pool, queue}) do
    :ets.insert(pool, conn)
    queue1 = :queue.in_r(conn, queue)
    {:noreply, {pool, queue1}}
  end

  def handle_info({:closed, {mod, socket}}, {pool, queue}) do
    obj = :ets.match_object(pool, {mod, socket})
    {item} = List.to_tuple(obj)
    :ets.delete_object(pool, item)
    queue1 = :queue.delete(item, queue)
    {:noreply, {pool, queue1}}
  end

  def handle_info(msg, state) do
    Logger.warning(fn ->
      "#{inspect(msg)}"
    end)
    {:noreply, state}
  end

end
