defmodule AshCommanded.Commanded.Sections.ProjectionsSection do
  @moduledoc """
  Defines the schema and entities for the `projections` section of the Commanded DSL.

  Projections define how events affect the resource state, transforming events into resource updates.
  """

  @projection_entity %Spark.Dsl.Entity{
    name: :projection,
    target: AshCommanded.Commanded.Projection,
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the projection, typically matching the event name"
      ],
      event_name: [
        type: :atom,
        doc: "The name of the event this projection listens for. Defaults to the projection name."
      ],
      action: [
        type: :atom,
        required: true,
        doc: "The Ash action to call when handling this event (e.g., :create, :update, :destroy)"
      ],
      changes: [
        type: {:or, [:map, :quoted]},
        required: true,
        doc:
          "The changes to apply to the resource when the event is received. Can be a static map or a function (in quoted form) that accepts the event and returns a map."
      ],
      autogenerate?: [
        type: :boolean,
        default: true,
        doc: "Whether to autogenerate a projector for this projection"
      ]
    ],
    imports: []
  }

  def schema do
    [
      projections: [
        type: {:list, :any},
        default: [],
        doc: "The projections that define how events affect resource state"
      ]
    ]
  end

  def entities do
    [@projection_entity]
  end
end
