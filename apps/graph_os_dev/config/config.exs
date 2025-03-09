import Config

# Configures the endpoint
config :graph_os_dev, GraphOS.DevWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: GraphOS.Dev.ErrorHTML, json: GraphOS.Dev.ErrorJSON],
    layout: false
  ],
  pubsub_server: GraphOS.Dev.PubSub,
  live_view: [signing_salt: "RMRKcvFz"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  graph_os_dev: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../../../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  graph_os_dev: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
