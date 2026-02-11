defmodule AshCommanded.Commanded.Sections.EventsSectionTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Sections.EventsSection

  describe "schema/0" do
    test "returns the events schema configuration" do
      schema = EventsSection.schema()

      assert is_list(schema)
      assert Keyword.has_key?(schema, :events)

      events_config = Keyword.get(schema, :events)
      assert Keyword.get(events_config, :type) == {:list, :any}
      assert Keyword.get(events_config, :default) == []
      assert is_binary(Keyword.get(events_config, :doc))
    end
  end

  describe "entities/0" do
    test "returns the event entity configuration" do
      entities = EventsSection.entities()

      assert is_list(entities)
      assert length(entities) == 1

      [event_entity] = entities
      assert event_entity.name == :event
      assert event_entity.target == AshCommanded.Commanded.Event
      assert event_entity.args == [:name]

      # Check schema field definitions
      schema = event_entity.schema
      assert Keyword.has_key?(schema, :name)
      assert Keyword.has_key?(schema, :fields)
      assert Keyword.has_key?(schema, :event_name)

      # Check types
      assert Keyword.get(schema[:name], :type) == :atom
      assert Keyword.get(schema[:fields], :type) == {:list, :atom}
      assert Keyword.get(schema[:event_name], :type) == :atom
    end
  end
end
