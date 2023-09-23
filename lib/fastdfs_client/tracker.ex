defmodule FastdfsClient.Tracker do

  require FastdfsClient.Helper

  def upload_file(file, file_ext_name, file_size) do
    conn_tracker = FastdfsClient.Registry.checkout()
    case FastdfsClient.Protocol.get_upload_storage(conn_tracker) do
      {:ok, {ip_addr, port, group_name, store_path_index}} ->
        case FastdfsClient.Storage.connect(ip_addr, port) do
          {:ok, conn_storage} ->
            FastdfsClient.Protocol.upload_file({conn_storage, group_name, store_path_index}, file, file_ext_name, file_size)

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  def download_file(group_name, remote_file_id) do
    conn_tracker = FastdfsClient.Registry.checkout()
    case FastdfsClient.Protocol.get_fetch_storage(conn_tracker, group_name, remote_file_id) do
      {:ok, {ip_addr, port, group_name}} ->
        case FastdfsClient.Storage.connect(ip_addr, port) do
          {:ok, conn_storage} ->
            FastdfsClient.Protocol.download_file(conn_storage, group_name, remote_file_id)

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  def delete_file(group_name, remote_file_id) do
    conn_tracker = FastdfsClient.Registry.checkout()
    case FastdfsClient.Protocol.get_fetch_storage(conn_tracker, group_name, remote_file_id) do
      {:ok, {ip_addr, port, group_name}} ->
        case FastdfsClient.Storage.connect(ip_addr, port) do
          {:ok, conn_storage} ->
            FastdfsClient.Protocol.delete_file(conn_storage, group_name, remote_file_id)

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

end
