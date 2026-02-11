defmodule AshCommanded.Commanded.Snapshot do
  @moduledoc """
  Represents a snapshot of an aggregate's state at a specific point in time.

  Snapshots are used as a performance optimization to avoid replaying all events
  from the beginning of the aggregate's history. Instead, a snapshot represents
  the aggregate state as of a specific version, allowing the system to load the
  snapshot and only replay events that occurred after the snapshot was taken.
  """

  @type t :: %__MODULE__{
          source_uuid: String.t(),
          source_type: module(),
          source_version: integer(),
          state: map(),
          version: integer(),
          created_at: DateTime.t()
        }

  defstruct [
    # The unique identifier for the aggregate
    :source_uuid,
    # The aggregate module
    :source_type,
    # The snapshot format version (for schema evolution)
    :source_version,
    # The serialized aggregate state
    :state,
    # The aggregate version (event number)
    :version,
    # When the snapshot was created
    :created_at
  ]

  @doc """
  Creates a new snapshot from an aggregate state.

  ## Parameters

  * `aggregate` - The aggregate state
  * `source_type` - The aggregate module
  * `version` - The aggregate version (event number)
  * `source_version` - The snapshot schema version

  ## Returns

  A new snapshot structure

  ## Examples

      iex> aggregate = %MyApp.UserAggregate{id: "123", name: "John"}
      iex> AshCommanded.Commanded.Snapshot.new(aggregate, MyApp.UserAggregate, 5, 1)
      %AshCommanded.Commanded.Snapshot{
        source_uuid: "123",
        source_type: MyApp.UserAggregate,
        source_version: 1,
        state: %MyApp.UserAggregate{id: "123", name: "John"},
        version: 5,
        created_at: ~U[2023-01-01 00:00:00Z]
      }
  """
  @spec new(map(), module(), integer(), integer()) :: t()
  def new(aggregate, source_type, version, source_version \\ 1) do
    # Extract the aggregate's ID - typically :id but could be configurable
    source_uuid = Map.get(aggregate, :id)

    unless source_uuid do
      raise ArgumentError, "Aggregate must have an :id field to create a snapshot"
    end

    %__MODULE__{
      source_uuid: source_uuid,
      source_type: source_type,
      source_version: source_version,
      state: aggregate,
      version: version,
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Extracts the aggregate state from a snapshot.

  ## Parameters

  * `snapshot` - The snapshot to extract state from

  ## Returns

  The aggregate state

  ## Examples

      iex> snapshot = %AshCommanded.Commanded.Snapshot{state: %{id: "123", name: "John"}}
      iex> AshCommanded.Commanded.Snapshot.state(snapshot)
      %{id: "123", name: "John"}
  """
  @spec state(t()) :: map()
  def state(%__MODULE__{state: state}), do: state

  @doc """
  Gets the aggregate version from a snapshot.

  ## Parameters

  * `snapshot` - The snapshot to get the version from

  ## Returns

  The aggregate version

  ## Examples

      iex> snapshot = %AshCommanded.Commanded.Snapshot{version: 5}
      iex> AshCommanded.Commanded.Snapshot.version(snapshot)
      5
  """
  @spec version(t()) :: integer()
  def version(%__MODULE__{version: version}), do: version

  @doc """
  Gets the source UUID (aggregate ID) from a snapshot.

  ## Parameters

  * `snapshot` - The snapshot to get the UUID from

  ## Returns

  The source UUID

  ## Examples

      iex> snapshot = %AshCommanded.Commanded.Snapshot{source_uuid: "123"}
      iex> AshCommanded.Commanded.Snapshot.source_uuid(snapshot)
      "123"
  """
  @spec source_uuid(t()) :: String.t()
  def source_uuid(%__MODULE__{source_uuid: uuid}), do: uuid
end
