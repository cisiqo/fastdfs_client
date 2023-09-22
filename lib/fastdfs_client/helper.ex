defmodule FastdfsClient.Helper do

  def parse_string_proto(body) do
    body
      |> :binary.bin_to_list
      |> :string.trim(:trailing, [0])
      |> :binary.list_to_bin
  end

  def encode_string_proto(string, size) do
    charlist = String.to_charlist(string)
    len = length(charlist)
    padding = <<0::size(8)>>
    charlist = charlist ++ List.duplicate(padding, size - len)
    :erlang.list_to_binary(charlist)
  end

  def file_ext_name(file_name) do
    file_name
      |> :filename.extension()
      |> String.replace(".", "")
  end

  def split_file_id(file_name) do
    split_name = String.split(file_name, "/", parts: 2)
    if List.first(split_name) == "" do
      String.split(List.last(split_name), "/", parts: 2)
    else
      split_name
    end
  end

end
