defmodule FastdfsClient.Protocol do

  @tracker_proto_cmd_resp 100
  @tracker_proto_cmd_service_query_store_without_group_one 101
  @tracker_proto_cmd_service_query_fetch_one 102

  @fdfs_proto_cmd_active_test 111
  @storage_proto_cmd_upload_file 11
  @storage_proto_cmd_delete_file 12
  @storage_proto_cmd_download_file 14

  @socket_opts [packet: :raw, mode: :binary, active: :once]

  alias FastdfsClient.Connection, as: Conn
  require Logger
  require FastdfsClient.Helper
  import Kernel, except: [send: 2]


  def connect(%Conn{host: host, port: port, socket_opts: socket_opts} = conn) do
    host = host |> to_charlist
    conn = %{conn | host: host, port: port, socket_opts: socket_opts}

    case :gen_tcp.connect(host, port, socket_opts ++ @socket_opts, conn.timeout) do
      {:ok, socket} ->
        Logger.info(fn -> "Established connection to #{host}" end)
        {:ok, %{conn | socket: {:gen_tcp, socket}}}

      {:error, _} = error ->
        error
    end
  end

  def disconnect(info, {mod, socket}) do
    :ok = mod.close(socket)

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)

      {:error, _} = error ->
        error

    end
  end

  def active_test(%Conn{socket: {mod, socket}} = conn) do
    :ok = mod.send(socket, <<0 :: size(64), @fdfs_proto_cmd_active_test, 0>>)
    {:ok, conn}
  end

  def get_upload_storage({mod, socket}) do
    :ok = mod.send(socket, <<0 :: size(64), @tracker_proto_cmd_service_query_store_without_group_one, 0>>)
    :inet.setopts(socket, [{:active, false}])
    case mod.recv(socket, 0) do
      {:ok, _} = recv ->
        {:ok, <<pkg_len :: 64-integer, cmd :: 8-integer, status :: 8-integer, body :: binary>>} = recv
        :inet.setopts(socket, [{:active, :once}])
        if status != 0 and cmd == @tracker_proto_cmd_resp do
          {:error, "Get storage server failed"}
        else
          <<group_name :: size(16 * 8), ip_addr :: size(15 * 8), port :: 64-integer, store_path_index :: 8-integer>> = String.slice(body, 0, pkg_len)
          group_name = FastdfsClient.Helper.parse_string_proto(<<group_name :: size(16 * 8)>>)
          ip_addr = FastdfsClient.Helper.parse_string_proto(<<ip_addr :: size(15 * 8)>>)
          {:ok, {ip_addr, port, group_name, store_path_index}}
        end

      {:error, :closed} ->
        Kernel.send(FastdfsClient.Registry, {:closed, {mod, socket}})
        {:error, "Fastdfs tracker server connected failed"}

      {:error, _} = error ->
        error
    end
  end

  def get_fetch_storage({mod, socket}, group_name, remote_file_id) do
    pkg_len = 16 + String.length(remote_file_id)
    header = <<pkg_len :: 64-integer, @tracker_proto_cmd_service_query_fetch_one, 0>>
    :ok = mod.send(socket, header)
    group_name = FastdfsClient.Helper.encode_string_proto(group_name, 16)
    body = <<group_name :: binary, remote_file_id :: binary>>
    :ok = mod.send(socket, body)
    :inet.setopts(socket, [{:active, false}])
    case mod.recv(socket, 0) do
      {:ok, _} = recv ->
        {:ok, <<pkg_len :: 64-integer, cmd :: 8-integer, status :: 8-integer, body :: binary>>} = recv
        :inet.setopts(socket, [{:active, :once}])
        if status != 0 and cmd == @tracker_proto_cmd_resp do
          {:error, "Get storage server failed"}
        else
          <<group_name :: size(16 * 8), ip_addr :: size(15 * 8), port :: 64-integer>> = String.slice(body, 0, pkg_len)
          group_name = FastdfsClient.Helper.parse_string_proto(<<group_name :: size(16 * 8)>>)
          ip_addr = FastdfsClient.Helper.parse_string_proto(<<ip_addr :: size(15 * 8)>>)
          {:ok, {ip_addr, port, group_name}}
        end

      {:error, :closed} ->
        Kernel.send(FastdfsClient.Registry, {:closed, {mod, socket}})
        {:error, "Fastdfs tracker server connected failed"}

      {:error, _} = error ->
        error
    end
  end

  def upload_file({%Conn{socket: {mod, socket}}, _group_name, store_path_index}, file, file_ext_name, file_size) do
    pkg_len = file_size + 15
    cmd = @storage_proto_cmd_upload_file
    status = 0
    header = <<pkg_len :: 64-integer, cmd :: 8-integer, status :: 8-integer>>
    :ok = mod.send(socket, header)
    file_ext_name = FastdfsClient.Helper.encode_string_proto(file_ext_name, 6)
    body = <<store_path_index :: 8-integer, file_size :: 64-integer, file_ext_name :: binary, file :: binary>>
    :ok = mod.send(socket, body)
    :inet.setopts(socket, [{:active, false}])
    case mod.recv(socket, 0) do
      {:ok, _} = recv ->
        {:ok, <<pkg_len :: 64-integer, cmd :: size(8), status :: 8-integer, body :: binary>>} = recv
        :inet.setopts(socket, [{:active, :once}])
        if status != 0 and cmd == @tracker_proto_cmd_resp do
          {:error, "Upload file failed"}
        else
          <<group_name :: size(16 * 8), fdfs_remote_id :: binary>> = String.slice(body, 0, pkg_len)
          group_name = FastdfsClient.Helper.parse_string_proto(<<group_name :: size(16 * 8)>>)
          {:ok, group_name <> "/" <> fdfs_remote_id}
        end

      {:error, _} = error ->
        error
    end
  end

  def download_file(%Conn{socket: {mod, socket}}, group_name, remote_file_id) do
    pkg_len = 32 + String.length(remote_file_id)
    cmd = @storage_proto_cmd_download_file
    status = 0
    header = <<pkg_len :: 64-integer, cmd :: 8-integer, status :: 8-integer>>
    :ok = mod.send(socket, header)
    offset = <<0 :: 64-integer>>
    download_bytes = <<0 :: 64-integer>>
    group_name = FastdfsClient.Helper.encode_string_proto(group_name, 16)
    body = <<offset :: binary, download_bytes :: binary, group_name :: binary, remote_file_id :: binary>>
    :ok = mod.send(socket, body)
    :inet.setopts(socket, [{:active, false}])
    recv_header = mod.recv(socket, 10)
    {:ok, <<pkg_len :: 64-integer, cmd :: size(8), status :: 8-integer>>} = recv_header
    case mod.recv(socket, pkg_len, 1_000) do
      {:ok, content} ->
        :inet.setopts(socket, [{:active, :once}])
        if status != 0 and cmd == @tracker_proto_cmd_resp do
          {:error, "Download file failed"}
        else
          {:ok, content}
        end

      {:error, _} ->
        {:error,"File not exist or remote_file_id has wrong!"}
    end
  end

  def delete_file(%Conn{socket: {mod, socket}}, group_name, remote_file_id) do
    pkg_len = 16 + String.length(remote_file_id)
    cmd = @storage_proto_cmd_delete_file
    status = 0
    header = <<pkg_len :: 64-integer, cmd :: 8-integer, status :: 8-integer>>
    :ok = mod.send(socket, header)
    group_name = FastdfsClient.Helper.encode_string_proto(group_name, 16)
    body = <<group_name :: binary, remote_file_id :: binary>>
    :ok = mod.send(socket, body)
    :inet.setopts(socket, [{:active, false}])
    case mod.recv(socket, 0, 1_000) do
      {:ok, _} = recv ->
        {:ok, <<_pkg_len :: 64-integer, cmd :: size(8), status :: 8-integer>>} = recv
        :inet.setopts(socket, [{:active, :once}])
        if status != 0 and cmd == @tracker_proto_cmd_resp do
          {:error, "Delete file failed"}
        else
          :ok
        end

      {:error, _} ->
        {:error,"File not exist or remote_file_id has wrong!"}
    end
  end

  def send(%Conn{socket: {mod, socket}} = conn, data) do
    :ok = mod.send(socket, data)
    {:ok, conn}
  end

  def handle_message({:tcp, socket, data}, %{socket: {:gen_tcp, socket}} = conn) do
    <<_pkg_len :: size(64), cmd :: size(8), status :: 8-integer, body :: binary>> = data
    if status != 0 and cmd == @tracker_proto_cmd_resp do
      {:error, "Fastdfs tracker has someting wrong"}
    else
      {:ok, conn, body}
    end
  end

  def handle_message({:tcp_closed, socket}, %{socket: {:gen_tcp, socket}}) do
    {:error, :closed}
  end

  def handle_message({:tcp_error, socket, reason}, %{socket: {:gen_tcp, socket}}) do
    {:error, reason}
  end

  def handle_message(_, _), do: :unknown

end
