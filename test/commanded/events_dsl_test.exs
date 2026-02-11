defmodule AshCommanded.Commanded.EventsDslTest do
  use ExUnit.Case, async: true

  defmodule ResourceWithEvents do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :status, :atom, default: :inactive
    end

    commanded do
      events do
        event :user_registered do
          fields([:id, :email, :name])
        end

        event :email_changed do
          fields([:id, :email])
          event_name(:UserEmailUpdated)
        end

        event :user_deactivated do
          fields([:id])
        end
      end
    end
  end

  describe "events DSL" do
    test "resource can define events" do
      # Just checking that the module compiles successfully
      assert Code.ensure_loaded?(ResourceWithEvents)

      # Access the event DSL configuration
      events = Spark.Dsl.Extension.get_entities(ResourceWithEvents, [:commanded, :events])

      # Check that we have the correct number of events
      assert length(events) == 3

      # Find events by name and check their properties
      registered_event = Enum.find(events, &(&1.name == :user_registered))
      assert registered_event.fields == [:id, :email, :name]
      assert registered_event.event_name == nil

      email_event = Enum.find(events, &(&1.name == :email_changed))
      assert email_event.fields == [:id, :email]
      assert email_event.event_name == :UserEmailUpdated

      deactivated_event = Enum.find(events, &(&1.name == :user_deactivated))
      assert deactivated_event.fields == [:id]
    end
  end
end
