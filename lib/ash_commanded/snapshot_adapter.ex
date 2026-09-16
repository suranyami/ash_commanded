defmodule AshCommanded.SnapshotAdapter do
  @moduledoc """
  Adapter to integrate AshCommanded's snapshot functionality with Commanded.

  This module implements the necessary callbacks to allow Commanded to
  use AshCommanded's snapshot functionality during aggregate initialization
  and event application.

  These four functions (`snapshot_version/1`, `snapshot_threshold/1`,
  `take_snapshot/2`, `load_snapshot/2`) follow the naming and arity of a
  hypothetical `Commanded.Aggregates.Aggregate.Snapshotter` behaviour, but no
  such module exists anywhere in `commanded` 1.4.11 (verified against
  `deps/commanded`) — Commanded's real snapshotting is internal
  (`Commanded.Snapshotting`), configured per-aggregate via a plain map, with
  no pluggable adapter behaviour to implement. This module cannot declare
  `@behaviour Commanded.Aggregates.Aggregate.Snapshotter`; doing so raises a
  "behaviour does not exist" compile warning because the module it names has
  never existed. Tracked as a Phase 4 concern alongside SNAP-01..03.
  """

  alias AshCommanded.Snapshot
  alias AshCommanded.SnapshotStore

  @doc """
  Returns the snapshot schema version for an aggregate module.

  ## Parameters

  * `aggregate_module` - The aggregate module

  ## Returns

  The snapshot schema version
  """
  # Not @impl true — no real Commanded behaviour exists to implement (see moduledoc)
  def snapshot_version(aggregate_module) do
    if function_exported?(aggregate_module, :snapshot_version, 0) do
      aggregate_module.snapshot_version()
    else
      1
    end
  end

  @doc """
  Returns the snapshot threshold for an aggregate module.

  ## Parameters

  * `aggregate_module` - The aggregate module

  ## Returns

  The number of events to process before taking a snapshot, or nil if 
  snapshotting is disabled
  """
  # Not @impl true — no real Commanded behaviour exists to implement (see moduledoc)
  def snapshot_threshold(aggregate_module) do
    if function_exported?(aggregate_module, :snapshot_threshold, 0) do
      aggregate_module.snapshot_threshold()
    else
      nil
    end
  end

  @doc """
  Takes a snapshot of an aggregate's state.

  ## Parameters

  * `aggregate_module` - The aggregate module
  * `aggregate_state` - The current state of the aggregate

  ## Returns

  * `{:ok, snapshot}` - If the snapshot was taken successfully
  * `{:error, reason}` - If the snapshot could not be taken
  """
  # Not @impl true — no real Commanded behaviour exists to implement (see moduledoc)
  def take_snapshot(aggregate_module, aggregate_state) do
    if function_exported?(aggregate_module, :create_snapshot, 1) do
      snapshot = aggregate_module.create_snapshot(aggregate_state)
      SnapshotStore.save_snapshot(snapshot)
      {:ok, snapshot}
    else
      {:error, :not_supported}
    end
  end

  @doc """
  Loads a snapshot for an aggregate.

  ## Parameters

  * `aggregate_module` - The aggregate module
  * `aggregate_uuid` - The unique identifier of the aggregate

  ## Returns

  * `{:ok, version, state}` - If a snapshot was found
  * `{:error, reason}` - If no snapshot was found or could not be loaded
  """
  # Not @impl true — no real Commanded behaviour exists to implement (see moduledoc)
  def load_snapshot(aggregate_module, aggregate_uuid) do
    if function_exported?(aggregate_module, :get_snapshot, 1) &&
         function_exported?(aggregate_module, :restore_from_snapshot, 1) do
      case aggregate_module.get_snapshot(aggregate_uuid) do
        {:ok, snapshot} ->
          state = aggregate_module.restore_from_snapshot(snapshot)
          {:ok, Snapshot.version(snapshot), state}

        :error ->
          {:error, :snapshot_not_found}
      end
    else
      {:error, :not_supported}
    end
  end
end
