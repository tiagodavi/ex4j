defmodule Ex4j.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    config = Application.get_env(:ex4j, Boltx)
    children = build_children(config)
    opts = [strategy: :one_for_one, name: Ex4j.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp build_children(nil) do
    Logger.warning(
      "Ex4j: No Boltx connection configuration found. Set config :ex4j, Boltx, [...]"
    )

    []
  end

  defp build_children(config) do
    # Register the Boltx pool with Ex4j.Bolt as the name
    config = Keyword.put(config, :name, Ex4j.Bolt.pool_name())
    [{Boltx, config}]
  end
end
