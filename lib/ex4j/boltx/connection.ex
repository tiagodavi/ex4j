# Overrides Boltx.Connection from boltx 0.0.6 to fix:
# - Missing format_error/1 callback (required by Boltx.Error.message/1)
# - e.message struct access bug in execute/4 rescue clause
# - No Bolt routing support (required for Neo4j Aura / neo4j+s:// scheme)
# - Ping/query db selection for Aura
# Remove this file once Boltx ships fixes for these issues.
defmodule Boltx.Connection do
  @moduledoc false
  use DBConnection

  import Boltx.BoltProtocol.ServerResponse

  alias Boltx.Client
  alias Boltx.Response

  @route_signature 0x66

  defstruct [
    :client,
    :server_version,
    :hints,
    :patch_bolt,
    :connection_id
  ]

  @impl true
  def connect(opts) do
    config = Client.Config.new(opts)

    with {:ok, %Client{} = client} <- Client.connect(config),
         {:ok, response_server_metadata} <- do_init(client, opts),
         {:ok, client} <- maybe_route(client, config, opts) do
      state = get_server_metadata_state(response_server_metadata)
      {:ok, %__MODULE__{state | client: client}}
    end
  end

  @impl true
  def handle_begin(opts, %__MODULE__{client: client} = state) do
    extra_parameters = opts[:extra_parameters] || %{}
    {:ok, _} = Client.send_begin(client, extra_parameters)
    {:ok, :began, state}
  end

  @impl true
  def handle_commit(_, %__MODULE__{client: client} = state) do
    {:ok, _} = Client.send_commit(client)
    {:ok, :committed, state}
  end

  @impl true
  def handle_rollback(_, %__MODULE__{client: client} = state) do
    {:ok, _} = Client.send_rollback(client)
    {:ok, :rolledback, state}
  end

  @impl true
  def handle_execute(query, params, opts, state) do
    case execute(query, params, opts, state) do
      {:ok, _} = result ->
        result(result, query, state)

      other ->
        other
    end
  end

  @impl true
  def disconnect(_reason, state) do
    if state.client.bolt_version >= 3.0 do
      Client.send_goodbye(state.client)
    end

    Client.disconnect(state.client)
  end

  @impl true
  def checkout(state) do
    {:ok, state}
  end

  @impl true
  def ping(state) do
    db = Application.get_env(:ex4j, :database)
    extra = if db, do: %{db: db}, else: %{}

    case Client.run_statement(state.client, "RETURN true as success", %{}, extra) do
      {:ok, statement_result(result_pull: pull_result(records: [[true]]))} ->
        {:ok, state}

      _ ->
        {:disconnect, Boltx.Error.wrap(__MODULE__, :db_ping_failed), state}
    end
  end

  def checkin(state) do
    case Client.disconnect(state.client) do
      :ok -> {:ok, state}
    end
  end

  @impl true
  def handle_prepare(query, _opts, state), do: {:ok, query, state}
  @impl true
  def handle_close(query, _opts, state), do: {:ok, query, state}
  @impl true
  def handle_deallocate(query, _cursor, _opts, state), do: {:ok, query, state}
  @impl true
  def handle_declare(query, _params, _opts, state), do: {:ok, query, state, nil}
  @impl true
  def handle_fetch(query, _cursor, _opts, state), do: {:cont, query, state}
  @impl true
  def handle_status(_opts, state), do: {:idle, state}

  def format_error(:db_ping_failed), do: "Neo4j ping failed (connection lost or unreachable)"
  def format_error(code), do: "Boltx connection error: #{inspect(code)}"

  # --- Bolt Routing -----------------------------------------------------------
  # The neo4j:// and neo4j+s:// schemes require a ROUTE step to discover which
  # server actually hosts the database. Without this, queries hit the routing
  # entry point which returns "Database not found".

  defp maybe_route(client, config, opts) do
    if routing_scheme?(config.scheme) do
      do_route(client, config, opts)
    else
      {:ok, client}
    end
  end

  defp routing_scheme?("neo4j"), do: true
  defp routing_scheme?("neo4j+s"), do: true
  defp routing_scheme?("neo4j+ssc"), do: true
  defp routing_scheme?(_), do: false

  defp do_route(client, config, opts) do
    db = Application.get_env(:ex4j, :database)
    routing_context = %{"address" => "#{config.hostname}:#{config.port}"}
    db_context = if db, do: %{"db" => db}, else: %{}

    encoded = Boltx.BoltProtocol.MessageEncoder.encode(@route_signature, [routing_context, [], db_context])
    :ok = Client.send_data(client, encoded)

    case Client.recv_packets(client, fn _ver, msgs -> {:ok, msgs} end, :infinity) do
      {:ok, [success: %{"rt" => routing_table}]} ->
        connect_to_routed_server(routing_table, config, opts)

      _ ->
        # Routing failed — fall back to the current connection
        {:ok, client}
    end
  end

  defp connect_to_routed_server(%{"servers" => servers}, config, opts) do
    # Pick the first WRITE server address
    write_address =
      servers
      |> Enum.find(fn s -> s["role"] == "WRITE" end)
      |> then(fn
        %{"addresses" => [addr | _]} -> addr
        _ -> nil
      end)

    case write_address do
      nil ->
        {:error, Boltx.Error.wrap(__MODULE__, :no_write_server)}

      address ->
        [host, port_str] = String.split(address, ":")
        port = String.to_integer(port_str)

        routed_config = %{config | hostname: host, port: port}

        with {:ok, %Client{} = new_client} <- Client.connect(routed_config),
             {:ok, _} <- do_init(new_client, opts) do
          {:ok, new_client}
        end
    end
  end

  # --- Query execution --------------------------------------------------------

  defp execute(statement, params, _opts, state) do
    %__MODULE__{client: client} = state

    case Client.run_statement(client, statement, params) do
      {:ok, statement_result} ->
        {:ok, statement_result}

      {:error, %Boltx.Error{code: error_code} = error} ->
        action =
          if client.bolt_version >= 3.0,
            do: &Client.send_reset/1,
            else: &Client.send_ack_failure/1

        if error_code in [:syntax_error, :semantic_error] do
          action.(client)
        end

        {:error, error, state}
    end
  rescue
    e in Boltx.Error ->
      {:error, %{code: :failure, message: "#{Exception.message(e)}, code: #{e.code}"}, state}

    e ->
      {:error, %{code: :failure, message: e}}
  end

  defp result(
         {:ok, statement_result() = statement_result},
         query,
         state
       ) do
    {:ok, query, Response.new(statement_result), state}
  end

  defp result(
         {:ok, statement_results},
         query,
         state
       )
       when is_list(statement_results) do
    {:ok, query,
     Enum.reduce(statement_results, [], fn result, acc ->
       [Response.new(result) | acc]
     end), state}
  end

  # --- Init (HELLO / LOGON) ---------------------------------------------------

  defp do_init(client, opts) do
    do_init(client.bolt_version, client, opts)
  end

  defp do_init(bolt_version, client, opts) when is_float(bolt_version) and bolt_version >= 5.1 do
    with {:ok, response_hello} <- Client.send_hello(client, opts),
         {:ok, _response_logon} <- Client.send_logon(client, opts) do
      {:ok, response_hello}
    end
  end

  defp do_init(bolt_version, client, opts) when is_float(bolt_version) and bolt_version >= 3.0 do
    Client.send_hello(client, opts)
  end

  defp do_init(bolt_version, client, opts) when is_float(bolt_version) and bolt_version <= 2.0 do
    Client.send_init(client, opts)
  end

  defp get_server_metadata_state(response_metadata) do
    patch_bolt = Map.get(response_metadata, "patch_bolt", "")
    hints = Map.get(response_metadata, "hints", "")
    connection_id = Map.get(response_metadata, "connection_id", "")

    %__MODULE__{
      client: nil,
      server_version: response_metadata["server"],
      patch_bolt: patch_bolt,
      hints: hints,
      connection_id: connection_id
    }
  end
end
