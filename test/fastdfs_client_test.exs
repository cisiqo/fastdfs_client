defmodule FastdfsClientTest do
  use ExUnit.Case
  doctest FastdfsClient

  test "greets the world" do
    assert FastdfsClient.hello() == :world
  end
end
