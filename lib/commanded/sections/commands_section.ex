defmodule AshCommanded.Commanded.Sections.CommandsSection do
  @moduledoc """
  Defines the schema and entities for the `commands` section of the Commanded DSL.

  Commands define the actions that can be performed on a resource and correspond to commands
  in the Commanded CQRS/ES library.
  """

  defp command_entity do
    %Spark.Dsl.Entity{
      name: :command,
      target: AshCommanded.Commanded.Command,
      args: [:name],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "The name of the command, used for reference in the DSL"
        ],
        fields: [
          type: {:list, :atom},
          required: true,
          doc:
            "The fields that the command accepts, which should correspond to attributes in the resource"
        ],
        identity_field: [
          type: :atom,
          doc: "The field that uniquely identifies the aggregate instance this command targets"
        ],
        action: [
          type: :atom,
          doc: "The Ash action to call when handling this command. Defaults to the command name."
        ],
        action_type: [
          type: {:in, [:create, :update, :destroy, :read, :custom]},
          doc:
            "The type of action (:create, :update, :destroy, :read, or :custom). If not specified, inferred from the action name."
        ],
        param_mapping: [
          type: {:or, [:map, :quoted]},
          doc: "A map or function for transforming command fields to action params."
        ],
        command_name: [
          type: :atom,
          doc: "Override the auto-generated command module name"
        ],
        handler_name: [
          type: :atom,
          doc: "Override the auto-generated handler function name"
        ],
        autogenerate_handler?: [
          type: :boolean,
          default: true,
          doc: "Whether to autogenerate a handler for this command"
        ],
        middleware: [
          type: {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}},
          doc:
            "List of middleware to apply to this command. Each entry can be a module or {module, options} tuple."
        ],
        transforms: [
          type: {:list, :any},
          doc: "List of parameter transformations to apply (used internally)"
        ],
        validations: [
          type: {:list, :any},
          doc: "List of parameter validations to apply (used internally)"
        ],
        in_transaction?: [
          type: :boolean,
          default: false,
          doc: "Whether to execute the command in a transaction"
        ],
        repo: [
          type: :atom,
          doc: "The repository to use for transactions (required if in_transaction? is true)"
        ],
        transaction_timeout: [
          type: :integer,
          doc: "Transaction timeout in milliseconds"
        ],
        transaction_isolation_level: [
          type: {:in, [:read_committed, :repeatable_read, :serializable]},
          doc: "Transaction isolation level"
        ],
        # Context propagation options
        include_metadata?: [
          type: :boolean,
          default: true,
          doc: "Whether to include command metadata in the action context"
        ],
        include_aggregate?: [
          type: :boolean,
          default: true,
          doc: "Whether to include the aggregate state in the action context"
        ],
        include_command?: [
          type: :boolean,
          default: true,
          doc: "Whether to include the command itself in the action context"
        ],
        context_prefix: [
          type: :atom,
          doc: "An optional prefix for context keys to prevent collisions"
        ],
        static_context: [
          type: :map,
          doc: "Static context values to include in every action execution"
        ]
      ],
      entities: []
    }
  end

  def schema do
    [
      commands: [
        type: {:list, :any},
        default: [],
        doc: "The commands that can be performed on this resource"
      ],
      middleware: [
        type: {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}},
        default: [],
        doc:
          "List of middleware to apply to all commands in this resource. Each entry can be a module or {module, options} tuple."
      ],
      # Global transaction options that apply to all commands
      default_repo: [
        type: :atom,
        doc: "The default repository to use for transactions"
      ],
      default_transaction_timeout: [
        type: :integer,
        doc: "Default transaction timeout in milliseconds"
      ],
      default_transaction_isolation_level: [
        type: {:in, [:read_committed, :repeatable_read, :serializable]},
        doc: "Default transaction isolation level"
      ]
    ]
  end

  def entities do
    [command_entity()]
  end
end
