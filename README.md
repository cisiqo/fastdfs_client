# FastdfsClient

A fastdfs client with elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fastdfs_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fastdfs_client, "~> 0.1.0"}
  ]
end
```

## Configuration

Add fastdfs server config to `config.exs`

```
config :fastdfs_client, :fdfs_server,
      host: "172.16.21.100",
      port: 22122
```

OR

```
config :fastdfs_client, :fdfs_server,
      endpoints: [
         {"172.16.21.100", 22122},
         {"172.16.21.101", 22122}
      ]
```

## Function

* upload_file/1
* download_file/1
* delete_file/1

