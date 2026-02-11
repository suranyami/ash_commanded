# Aggregate Snapshotting

AshCommanded supports [aggregate snapshotting](https://hexdocs.pm/commanded/aggregate-snapshotting.html) as a performance optimization for aggregates with many events. Snapshotting allows the system to store the current state of an aggregate at specific points and then only replay events that occurred after the snapshot was taken. This implementation follows the [Commanded snapshotting architecture](https://hexdocs.pm/commanded/aggregate-snapshotting.html).

## Why Use Snapshotting?

In event-sourced systems, aggregates rebuild their state by replaying all events from the beginning of time. This can become a performance issue for aggregates that have accumulated a large number of events over their lifetime.

Snapshotting addresses this by:

1. Capturing the aggregate state at a point in time
2. Storing this snapshot for future use
3. Only loading events that occurred after the snapshot was taken

This significantly improves performance for aggregates with many events.

## Enabling Snapshotting

Snapshotting is configured at the application level in your domain. Use the **Domain extension** `AshCommanded.Commanded.DomainDsl` so the `application` section is available and the Commanded application module is generated:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]

  resources do
    resource MyApp.User
  end

  commanded do
    application do
      otp_app :my_app
      event_store Commanded.EventStore.Adapters.EventStore
      
      # Enable snapshotting
      snapshotting true
      
      # Take a snapshot every 100 events (default)
      snapshot_threshold 100
      
      # Snapshot schema version (for future schema evolution)
      snapshot_version 1
      
      # Optional custom snapshot store module
      # snapshot_store MyApp.CustomSnapshotStore
    end
  end
end
```

## How Snapshotting Works

When snapshotting is enabled, the following happens (following Commanded's [snapshot loading process](https://hexdocs.pm/commanded/aggregate-snapshotting.html#how-it-works)):

1. **Command Execution**: When a command is sent to an aggregate, the system first checks if a snapshot exists for that aggregate.

2. **Snapshot Loading**: If a snapshot exists, the aggregate state is restored from the snapshot rather than rebuilding from scratch.

3. **Event Loading**: Only events that occurred after the snapshot's version are loaded and applied to the aggregate.

4. **Snapshot Creation**: After applying events, the system checks if a new snapshot should be taken based on the configured threshold.

## Snapshot Storage

By default, snapshots are stored in memory using an ETS table, similar to Commanded's [in-memory snapshot store](https://hexdocs.pm/commanded/aggregate-snapshotting.html#snapshot-storage). This is suitable for development but not for production. 

In a production environment, you should implement a custom snapshot store that persists snapshots to a database or other storage system, following Commanded's [snapshot adapter pattern](https://hexdocs.pm/commanded/aggregate-snapshotting.html#custom-snapshot-storage).

### Custom Snapshot Store

You can implement a custom snapshot store by creating a module that implements the `AshCommanded.Commanded.SnapshotStore` behaviour, which is based on Commanded's [Snapshot adapter](https://hexdocs.pm/commanded/Commanded.Snapshotting.Adapter.html) interface:

```elixir
defmodule MyApp.CustomSnapshotStore do
  @behaviour AshCommanded.Commanded.SnapshotStore
  
  # Get a snapshot by aggregate ID and type
  @impl true
  def get_snapshot(source_uuid, source_type) do
    # Implementation that retrieves from database
  end
  
  # Save a snapshot
  @impl true
  def save_snapshot(snapshot) do
    # Implementation that saves to database
  end
  
  # Delete all snapshots for an aggregate
  @impl true
  def delete_snapshots(source_uuid, source_type) do
    # Implementation that deletes from database
  end
  
  # Initialize the store
  @impl true
  def init(config) do
    # Implementation that initializes the store
  end
end
```

Then configure your domain to use it (in a Domain that has `extensions: [AshCommanded.Commanded.DomainDsl]`):

```elixir
commanded do
  application do
    # ... other settings ...
    snapshot_store MyApp.CustomSnapshotStore
  end
end
```

## Performance Considerations

- **Threshold**: The `snapshot_threshold` setting controls how frequently snapshots are taken. A lower value means more snapshots but potentially better performance for frequently accessed aggregates.

- **State Size**: Snapshots store the entire aggregate state, which can be large. Consider the storage requirements when enabling snapshotting.

- **Asynchronous Snapshots**: Snapshots are created asynchronously to avoid impacting command execution performance.

## Snapshot Format Evolution

The `snapshot_version` setting allows for future schema evolution. If you need to change the structure of your aggregates, you can increment this version number and add migration logic in your aggregate's `restore_from_snapshot/1` function.

## Example

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :email, :string
    attribute :name, :string
    attribute :status, :string
  end
  
  commanded do
    commands do
      command :register_user do
        fields [:id, :email, :name]
        identity_field :id
      end
      
      command :change_email do
        fields [:id, :email]
        identity_field :id
      end
    end
    
    events do
      event :user_registered do
        fields [:id, :email, :name]
      end
      
      event :email_changed do
        fields [:id, :email]
      end
    end
  end
end
```

With snapshotting enabled, after registering many users and changing emails multiple times, the system will automatically create snapshots when needed, improving command execution performance.