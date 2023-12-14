defmodule Ex4j.Application do
  require Logger

  @moduledoc false
  use Application

  def start(_type, _args) do
    config = Application.get_env(:ex4j, Bolt)
    children = build_children(config)
    opts = [strategy: :one_for_one, name: Ex4j.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp build_children(nil) do
    Logger.error("Ex4j: There's no connection configuration.")
    []
  end

  defp build_children(config) do
    [
      {Bolt.Sips, config}
    ]
  end
end
