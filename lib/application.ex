defmodule Ex4j.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    patch_boltx()

    config = Application.get_env(:ex4j, Boltx)
    children = build_children(config)
    opts = [strategy: :one_for_one, name: Ex4j.Supervisor]

    Supervisor.start_link(children, opts)
  end

  # Boltx 0.0.6 patches applied at runtime so they take effect regardless
  # of BEAM code-path ordering (critical when ex4j is used as a dependency).
  # Remove once Boltx ships fixes for these issues.
  defp patch_boltx do
    patch_boltx_error()
    ensure_patched_connection()
  end

  # Boltx.Error.message/1 calls module.format_error(code) but format_error/1
  # is not defined in Boltx.Connection or Boltx.Client.
  defp patch_boltx_error do
    :code.purge(Boltx.Error)
    :code.delete(Boltx.Error)

    previous = Code.compiler_options(ignore_module_conflict: true)

    Module.create(
      Boltx.Error,
      quote do
        @error_map %{
          "Neo.ClientError.Security.Unauthorized" => :unauthorized,
          "Neo.ClientError.Request.Invalid" => :request_invalid,
          "Neo.ClientError.Statement.SemanticError" => :semantic_error,
          "Neo.ClientError.Statement.SyntaxError" => :syntax_error
        }

        defexception [:module, :code, :bolt, :packstream]

        def wrap(module, code) when is_atom(code),
          do: %__MODULE__{module: module, code: code}

        def wrap(module, code) when is_binary(code),
          do: wrap(module, to_atom(code))

        def wrap(module, bolt_error) when is_map(bolt_error),
          do: %__MODULE__{
            module: module,
            code: bolt_error.code |> to_atom(),
            bolt: bolt_error
          }

        def wrap(module, code, packstream),
          do: %__MODULE__{module: module, code: code, packstream: packstream}

        def message(%__MODULE__{code: code, module: module, bolt: bolt}) do
          cond do
            is_map(bolt) and Map.has_key?(bolt, :message) ->
              bolt.message

            function_exported?(module, :format_error, 1) ->
              module.format_error(code)

            true ->
              "#{inspect(module)} error: #{inspect(code)}"
          end
        end

        def to_atom(error_message) do
          Map.get(@error_map, error_message, :unknown)
        end
      end,
      Macro.Env.location(__ENV__)
    )

    Code.compiler_options(previous)
  end

  # Our Boltx.Connection override (lib/ex4j/boltx/connection.ex) compiles into
  # ex4j's ebin but BEAM may load the original from boltx's ebin first.
  # Force-load our version so the patched ping/1 (with db support) is active.
  defp ensure_patched_connection do
    unless function_exported?(Boltx.Connection, :format_error, 1) do
      ebin = Application.app_dir(:ex4j, "ebin")
      beam = Path.join(ebin, "Elixir.Boltx.Connection") |> String.to_charlist()

      :code.purge(Boltx.Connection)
      :code.delete(Boltx.Connection)
      :code.load_abs(beam)
    end
  end

  defp build_children(nil) do
    Logger.warning(
      "Ex4j: No Boltx connection configuration found. Set config :ex4j, Boltx, [...]"
    )

    []
  end

  defp build_children(config) do
    {database, config} = Keyword.pop(config, :database)

    if database do
      Application.put_env(:ex4j, :database, database)
    end

    config =
      config
      |> Keyword.put(:name, Ex4j.Bolt.pool_name())
      |> rename_key(:url, :uri)
      |> rename_key(:basic_auth, :auth)

    [{Boltx, config}]
  end

  defp rename_key(keyword, old_key, new_key) do
    case Keyword.pop(keyword, old_key) do
      {nil, keyword} -> keyword
      {value, keyword} -> Keyword.put_new(keyword, new_key, value)
    end
  end
end
