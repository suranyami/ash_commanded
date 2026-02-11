defmodule AshCommanded.Commanded.SnapshotConfiguration do
  @moduledoc """
  Provides configuration options for Commanded to use AshCommanded's snapshot functionality.

  This module standardizes snapshot configuration options for Commanded applications.
  """

  @doc """
  Returns the snapshot options to use when configuring a Commanded application.

  ## Parameters

  * `threshold` - The number of events to process before taking a snapshot (default: 100)

  ## Returns

  A keyword list of snapshot options for Commanded

  ## Examples

      iex> AshCommanded.Commanded.SnapshotConfiguration.snapshot_options(500)
      [snapshot_every: 500, snapshot_module: AshCommanded.Commanded.SnapshotAdapter]
  """
  @spec snapshot_options(integer() | nil) :: Keyword.t()
  def snapshot_options(threshold \\ 100) do
    [
      snapshot_every: threshold,
      snapshot_module: AshCommanded.Commanded.SnapshotAdapter
    ]
  end

  @doc """
  Returns the snapshot options to use when dispatching a command.

  ## Returns

  A keyword list of snapshot options for command dispatch

  ## Examples

      iex> AshCommanded.Commanded.SnapshotConfiguration.dispatch_options()
      [snapshot_module: AshCommanded.Commanded.SnapshotAdapter]
  """
  @spec dispatch_options() :: Keyword.t()
  def dispatch_options do
    [
      snapshot_module: AshCommanded.Commanded.SnapshotAdapter
    ]
  end
end
