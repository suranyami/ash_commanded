defmodule AshCommanded.Commanded.Command do
  @moduledoc """
  Represents a command in the Commanded DSL.

  Commands define actions that can be performed on a resource, resulting in events.
  """

  @type t :: %__MODULE__{
          name: atom(),
          fields: [atom()],
          identity_field: atom() | nil,
          action: atom() | nil,
          action_type: :create | :update | :destroy | :read | :custom | nil,
          param_mapping: map() | (map() -> map()) | (map(), struct() -> map()) | nil,
          command_name: atom() | nil,
          handler_name: atom() | nil,
          autogenerate_handler?: boolean(),
          middleware: list(module() | {module(), map()}),
          transforms: list(tuple()),
          validations: list(tuple()),
          __spark_metadata__: any(),
          # Transaction options
          in_transaction?: boolean(),
          repo: atom() | nil,
          transaction_timeout: integer() | nil,
          transaction_isolation_level: :read_committed | :repeatable_read | :serializable | nil,
          # Context propagation options
          include_metadata?: boolean(),
          include_aggregate?: boolean(),
          include_command?: boolean(),
          context_prefix: atom() | nil,
          static_context: map() | nil
        }

  defstruct [
    :name,
    :fields,
    :identity_field,
    :action,
    :action_type,
    :param_mapping,
    :command_name,
    :handler_name,
    :__spark_metadata__,
    autogenerate_handler?: true,
    middleware: [],
    transforms: [],
    validations: [],
    # Transaction options
    in_transaction?: false,
    repo: nil,
    transaction_timeout: nil,
    transaction_isolation_level: nil,
    # Context propagation options
    include_metadata?: true,
    include_aggregate?: true,
    include_command?: true,
    context_prefix: nil,
    static_context: %{}
  ]
end
