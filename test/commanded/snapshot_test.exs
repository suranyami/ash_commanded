defmodule AshCommanded.Commanded.SnapshotTest do
  use ExUnit.Case

  alias AshCommanded.Commanded.Snapshot
  alias AshCommanded.Commanded.SnapshotStore

  # Define a test aggregate struct
  defmodule TestAggregate do
    defstruct [:id, :name, :email, :status, version: 0]
  end

  setup do
    # Initialize the snapshot store before each test
    SnapshotStore.init(%{})
    :ok
  end

  describe "Snapshot" do
    test "creates a new snapshot" do
      # Arrange
      aggregate = %TestAggregate{
        id: "test-123",
        name: "Test User",
        email: "test@example.com",
        status: "active",
        version: 42
      }

      # Act
      snapshot = Snapshot.new(aggregate, TestAggregate, 42)

      # Assert
      assert snapshot.source_uuid == "test-123"
      assert snapshot.source_type == TestAggregate
      assert snapshot.version == 42
      assert snapshot.state == aggregate
      assert %DateTime{} = snapshot.created_at
    end

    test "provides accessor functions" do
      # Arrange
      aggregate = %TestAggregate{id: "test-123", version: 42}
      snapshot = Snapshot.new(aggregate, TestAggregate, 42)

      # Act & Assert
      assert Snapshot.state(snapshot) == aggregate
      assert Snapshot.version(snapshot) == 42
      assert Snapshot.source_uuid(snapshot) == "test-123"
    end
  end

  describe "SnapshotStore" do
    test "saves and retrieves a snapshot" do
      # Arrange
      aggregate = %TestAggregate{id: "test-123", version: 42}
      snapshot = Snapshot.new(aggregate, TestAggregate, 42)

      # Act
      :ok = SnapshotStore.save_snapshot(snapshot)
      {:ok, retrieved_snapshot} = SnapshotStore.get_snapshot("test-123", TestAggregate)

      # Assert
      assert retrieved_snapshot.source_uuid == snapshot.source_uuid
      assert retrieved_snapshot.source_type == snapshot.source_type
      assert retrieved_snapshot.version == snapshot.version
      assert retrieved_snapshot.state == snapshot.state
    end

    test "returns error when no snapshot exists" do
      # Act
      result = SnapshotStore.get_snapshot("nonexistent", TestAggregate)

      # Assert
      assert result == :error
    end

    test "deletes snapshots" do
      # Arrange
      aggregate = %TestAggregate{id: "test-123", version: 42}
      snapshot = Snapshot.new(aggregate, TestAggregate, 42)
      :ok = SnapshotStore.save_snapshot(snapshot)

      # Act
      :ok = SnapshotStore.delete_snapshots("test-123", TestAggregate)
      result = SnapshotStore.get_snapshot("test-123", TestAggregate)

      # Assert
      assert result == :error
    end

    test "returns the latest snapshot when multiple exist" do
      # Arrange
      aggregate1 = %TestAggregate{id: "test-123", version: 42, status: "version1"}
      aggregate2 = %TestAggregate{id: "test-123", version: 84, status: "version2"}

      snapshot1 = Snapshot.new(aggregate1, TestAggregate, 42)
      snapshot2 = Snapshot.new(aggregate2, TestAggregate, 84)

      # Act
      :ok = SnapshotStore.save_snapshot(snapshot1)
      :ok = SnapshotStore.save_snapshot(snapshot2)
      {:ok, retrieved_snapshot} = SnapshotStore.get_snapshot("test-123", TestAggregate)

      # Assert
      assert retrieved_snapshot.version == 84
      assert retrieved_snapshot.state.status == "version2"
    end
  end
end
