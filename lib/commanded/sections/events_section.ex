defmodule AshCommanded.Commanded.Sections.EventsSection do
  @moduledoc """
  Defines the schema and entities for the `events` section of the Commanded DSL.

  Events represent facts that have occurred in the system and are emitted by commands.
  """

  @event_entity %Spark.Dsl.Entity{
    name: :event,
    target: AshCommanded.Commanded.Event,
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the event, used for reference in the DSL"
      ],
      fields: [
        type: {:list, :atom},
        required: true,
        doc:
          "The fields that the event contains, which should correspond to attributes in the resource"
      ],
      event_name: [
        type: :atom,
        doc: "Override the auto-generated event module name"
      ]
    ],
    imports: []
  }

  def schema do
    [
      events: [
        type: {:list, :any},
        default: [],
        doc: "The events that can be emitted by commands in this resource"
      ]
    ]
  end

  def entities do
    [@event_entity]
  end
end
