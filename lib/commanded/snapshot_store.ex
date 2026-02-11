defmodule AshCommanded.Commanded.SnapshotStore do
  @moduledoc """
  Defines the behavior and default implementation for aggregate snapshot storage.

  The snapshot store is responsible for storing and retrieving snapshots of aggregates,
  providing a performance optimization by allowing the system to load the latest snapshot
  rather than replaying all events from the beginning.

  The default implementation uses ETS tables for storage. Alternative implementations
  can be provided by specifying a custom snapshot store module in the application config.
  """

  alias AshCommanded.Commanded.Snapshot

  @doc """
  Gets the latest snapshot for an aggregate by its UUID.

  ## Parameters

  * `source_uuid` - The unique identifier of the aggregate
  * `source_type` - The aggregate module

  ## Returns

  * `{:ok, snapshot}` - If a snapshot was found
  * `:error` - If no snapshot was found
  """
  @callback get_snapshot(String.t(), module()) :: {:ok, Snapshot.t()} | :error

  @doc """
  Saves a snapshot of an aggregate.

  ## Parameters

  * `snapshot` - The snapshot to save

  ## Returns

  * `:ok` - If the snapshot was saved successfully
  * `{:error, reason}` - If the snapshot could not be saved
  """
  @callback save_snapshot(Snapshot.t()) :: :ok | {:error, any()}

  @doc """
  Deletes all snapshots for an aggregate.

  ## Parameters

  * `source_uuid` - The unique identifier of the aggregate
  * `source_type` - The aggregate module

  ## Returns

  * `:ok` - If the snapshots were deleted successfully
  * `{:error, reason}` - If the snapshots could not be deleted
  """
  @callback delete_snapshots(String.t(), module()) :: :ok | {:error, any()}

  @doc """
  Initializes the snapshot store.

  ## Parameters

  * `config` - Configuration options for the snapshot store

  ## Returns

  * `:ok` - If the snapshot store was initialized successfully
  * `{:error, reason}` - If the snapshot store could not be initialized
  """
  @callback init(any()) :: :ok | {:error, any()}

  # Default implementation using ETS
  @table_name :ash_commanded_snapshots

  @doc """
  Gets the latest snapshot for an aggregate by its UUID.

  ## Parameters

  * `source_uuid` - The unique identifier of the aggregate
  * `source_type` - The aggregate module

  ## Returns

  * `{:ok, snapshot}` - If a snapshot was found
  * `:error` - If no snapshot was found
  """
  @spec get_snapshot(String.t(), module()) :: {:ok, Snapshot.t()} | :error
  def get_snapshot(source_uuid, source_type) do
    ensure_table()

    # Use match_object with a proper pattern for the key
    pattern = {{source_uuid, source_type, :_}, :_}

    case :ets.match_object(@table_name, pattern) do
      [] ->
        :error

      snapshots ->
        # Find the snapshot with the highest version
        {_key, snapshot} =
          snapshots
          |> Enum.sort_by(fn {_key, %{version: version}} -> version end, :desc)
          |> List.first()

        {:ok, snapshot}
    end
  rescue
    e ->
      IO.puts("Error retrieving snapshot: #{inspect(e)}")
      :error
  end

  @doc """
  Saves a snapshot of an aggregate.

  ## Parameters

  * `snapshot` - The snapshot to save

  ## Returns

  * `:ok` - If the snapshot was saved successfully
  * `{:error, reason}` - If the snapshot could not be saved
  """
  @spec save_snapshot(Snapshot.t()) :: :ok | {:error, any()}
  def save_snapshot(%Snapshot{} = snapshot) do
    ensure_table()

    key = {snapshot.source_uuid, snapshot.source_type, snapshot.version}

    :ets.insert(@table_name, {key, snapshot})

    :ok
  rescue
    e ->
      {:error, "Failed to save snapshot: #{inspect(e)}"}
  end

  @doc """
  Deletes all snapshots for an aggregate.

  ## Parameters

  * `source_uuid` - The unique identifier of the aggregate
  * `source_type` - The aggregate module

  ## Returns

  * `:ok` - If the snapshots were deleted successfully
  * `{:error, reason}` - If the snapshots could not be deleted
  """
  @spec delete_snapshots(String.t(), module()) :: :ok | {:error, any()}
  def delete_snapshots(source_uuid, source_type) do
    ensure_table()

    # Match on the key pattern and delete matching records
    pattern = {{source_uuid, source_type, :_}, :_}
    :ets.match_delete(@table_name, pattern)

    :ok
  rescue
    e ->
      {:error, "Failed to delete snapshots: #{inspect(e)}"}
  end

  @doc """
  Initializes the snapshot store.

  ## Parameters

  * `config` - Configuration options for the snapshot store (unused for ETS implementation)

  ## Returns

  * `:ok` - If the snapshot store was initialized successfully
  """
  @spec init(any()) :: :ok
  def init(_config) do
    ensure_table()
    :ok
  end

  # Private functions

  defp ensure_table do
    if :ets.info(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :set, :public])
    end
  end
end
