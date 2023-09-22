defmodule FastdfsClient do

  def connect() do
    stracker  = Application.get_all_env(:fdfs_server)
    FastdfsClient.Pool.start_link(stracker)
  end

  def upload_file(file_name) do
    case File.exists?(file_name) do
      true ->
        {:ok, file} = File.read(file_name)
        {:ok, file_stat} = File.stat(file_name)
        file_size = file_stat.size
        file_ext_name = FastdfsClient.Helper.file_ext_name(file_name)
        case FastdfsClient.Tracker.upload_file(file, file_ext_name, file_size) do
          {:error, _} = error ->
            error

          {:ok, file_id} ->
            {:ok, file_id}
        end

      false ->
        {:error, "File not exists"}
    end
  end

  def download_file(file_name) do
    [group_name, remote_file_id] = FastdfsClient.Helper.split_file_id(file_name)
    case FastdfsClient.Tracker.download_file(group_name, remote_file_id) do
      {:error, _} = error ->
        error

      {:ok, content} ->
        {:ok, content}
    end
  end

  def delete_file(file_name) do
    [group_name, remote_file_id] = FastdfsClient.Helper.split_file_id(file_name)
    case FastdfsClient.Tracker.delete_file(group_name, remote_file_id) do
      {:error, _} = error ->
        error

      :ok ->
        :ok
    end
  end
end
