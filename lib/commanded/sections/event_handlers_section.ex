defmodule AshCommanded.Commanded.Sections.EventHandlersSection do
  @moduledoc """
  Defines the schema and entities for the `event_handlers` section of the Commanded DSL.

  Event handlers are general purpose responders to events that don't necessarily update
  resource state but can perform side effects or other operations.
  """

  @event_handler_entity %Spark.Dsl.Entity{
    name: :handler,
    target: AshCommanded.Commanded.EventHandler,
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the event handler"
      ],
      events: [
        type: {:list, :atom},
        required: true,
        doc: "List of event names this handler will subscribe to"
      ],
      handler_name: [
        type: :atom,
        doc: "Override the auto-generated handler module name"
      ],
      action: [
        type: {:or, [:quoted, :atom]},
        doc:
          "Action to perform when handling the event. Can be an Ash action name or a quoted function that receives the event and returns a result."
      ],
      publish_to: [
        type: {:or, [:atom, :string, {:list, {:or, [:atom, :string]}}]},
        doc: "Optional PubSub topic(s) to publish the event to"
      ],
      idempotent: [
        type: :boolean,
        default: false,
        doc:
          "Whether the handler is idempotent and can safely handle the same event multiple times"
      ],
      autogenerate?: [
        type: :boolean,
        default: true,
        doc: "Whether to autogenerate a handler for this configuration"
      ]
    ],
    imports: []
  }

  @doc """
  Returns the schema for the event_handlers section

  ## Examples

      iex> AshCommanded.Commanded.Sections.EventHandlersSection.schema()
      [
        event_handlers: [
          type: {:list, :any},
          default: [],
          doc: "The handlers that respond to events without necessarily updating resource state"
        ]
      ]
  """
  def schema do
    [
      event_handlers: [
        type: {:list, :any},
        default: [],
        doc: "The handlers that respond to events without necessarily updating resource state"
      ]
    ]
  end

  @doc """
  Returns the entities for the event_handlers section

  ## Examples

      iex> AshCommanded.Commanded.Sections.EventHandlersSection.entities()
      [%Spark.Dsl.Entity{name: :handler, ...}]
  """
  def entities do
    [@event_handler_entity]
  end
end
