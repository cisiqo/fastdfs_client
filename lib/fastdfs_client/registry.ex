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
        try do
          case :ets.match_object(pool, :"$1") do
            [] ->
              raise "Fastdfs server running away"

            all ->
              queue = :queue.from_list(all)
              {{:value, item}, queue1} = :queue.out_r(queue)
              {:reply, item, {pool, queue1}}
          end
        rescue
          e in RuntimeError -> e
        end

      {{:value, item}, queue1} ->
        {:reply, item, {pool, queue1}}
    end
  end

  def handle_cast({:checkin, conn}, {pool, queue}) do
    :ets.insert(pool, conn.socket)
    queue1 = :queue.in_r(conn.socket, queue)
    {:noreply, {pool, queue1}}
  end

  def handle_info({:DOWN, _ref, _type, pid, _reason}, {pool, queue}) do
    obj = :ets.match_object(pool, {:_, pid})
    {item} = List.to_tuple(obj)
    :ets.delete_object(pool, item)
    queue1 = :queue.delete(item, queue)
    {:noreply, {pool, queue1}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

end
