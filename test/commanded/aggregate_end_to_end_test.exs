defmodule AshCommanded.AggregateEndToEndTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshCommanded.TestSupport.Commands.CreateWidget
  alias AshCommanded.TestSupport.Events.WidgetCreated
  alias AshCommanded.TestSupport.Widget
  alias AshCommanded.TestSupport.WidgetAggregate

  test "a create_widget command travels through the generated aggregate into real Ash state" do
    assert Code.ensure_loaded?(WidgetAggregate)

    id = Ash.UUID.generate()
    aggregate = struct(WidgetAggregate)
    command = struct(CreateWidget, id: id, name: "Left-Handed Screwdriver")

    assert {:ok, %WidgetCreated{} = event} = WidgetAggregate.execute(aggregate, command)
    assert event.id == id
    assert event.name == "Left-Handed Screwdriver"

    persisted = Ash.get!(Widget, id)
    assert persisted.name == "Left-Handed Screwdriver"

    new_state = WidgetAggregate.apply(aggregate, event)
    assert new_state.id == command.id
  end
end
