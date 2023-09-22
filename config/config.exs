# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration

import Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration
#
#     config :fdfs_server,
#       host: "172.16.21.100",
#       port: 22122

# Sample configuration with endpoint
#
#     config :fdfs_server
#       endpoints: [
#         {"172.16.21.100", 22122},
#         {"172.16.21.101", 22122}
#       ]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config :fdfs_server,
  host: "172.16.21.100"
