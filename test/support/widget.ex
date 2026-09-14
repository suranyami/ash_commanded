defmodule AshCommanded.TestSupport.Widget do
  @moduledoc false
  use Ash.Resource,
    domain: AshCommanded.TestSupport.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshCommanded.Commanded.Dsl]

  ets do
    private? true
  end

  commanded do
    commands do
      command :create_widget do
        fields([:id, :name])
        identity_field(:id)
        action :create
        event :widget_created
      end

      command :update_widget do
        fields([:id, :name])
        identity_field(:id)
        action :update
        event :widget_updated
      end

      command :destroy_widget do
        fields([:id])
        identity_field(:id)
        action :destroy
        event :widget_destroyed
      end
    end

    events do
      event :widget_created do
        fields([:id, :name])
      end

      event :widget_updated do
        fields([:id, :name])
      end

      event :widget_destroyed do
        fields([:id])
      end
    end

    # Minimal projection + event handler so Plan 01-06's Task 3 can call the generated
    # projector/event-handler `handle/2` functions directly. No other plan in this wave edits
    # this file.
    #
    # Uses `:widget_updated` (not `:widget_created`) for the projection: the projector's
    # generated `handle/2` for a `:create`-action projection passes the resource MODULE to
    # `apply/2` (creating a brand-new record), which would be a second, redundant creation path
    # alongside the command-driven one `aggregate_end_to_end_test.exs` already exercises. Using
    # `:update` instead requires an existing record — proving the projector actually reads
    # (`Ash.get`), transforms, and re-persists, a strictly more thorough exercise of the
    # generated code.
    projections do
      projection :widget_updated do
        action :update
        changes(fn event -> %{name: event.name} end)
      end
    end

    # Uses a quoted lambda `action`, not an atom action reference: the generated event-handler
    # `execute_action/2` path for atom actions calls `Ash.run_action/3`, a function that does not
    # exist (a pre-existing, out-of-scope defect — see deferred-items.md "From Plan 01-03"). The
    # lambda form bypasses `execute_action/2` entirely, so it is unaffected by that defect and
    # correctly proves the generated handler module dispatches to the declared side effect.
    event_handlers do
      handler :widget_notifier do
        events([:widget_created])

        action fn event, _metadata ->
          send(self(), {:widget_notified, event.id})
          :ok
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: [:id, :name], update: [:name]]
  end

  attributes do
    # `uuid_primary_key/1` hides every option but `:name` and defaults `writable?` to
    # false, so it cannot accept a client-supplied id (needed here: the aggregate's
    # identity comes from the dispatched command, not from Ash). Declare it explicitly
    # instead, writable, so `create: [:id, :name]` below can actually accept it.
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      writable? true
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :name, :string, public?: true
  end
end
