# Commands

Commands in AshCommanded represent intentions to change the state of your application. They are the input side of the [CQRS pattern](https://martinfowler.com/bliki/CQRS.html). In Commanded, [commands](https://hexdocs.pm/commanded/commands.html) are the primary way to make changes to your domain.

## Defining Commands

Commands are defined in the `commanded` DSL extension for Ash resources:

```elixir
defmodule ECommerce.Customer do
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
      command :register_customer do
        fields([:id, :email, :name])
        identity_field(:id)
      end

      command :update_status do
        fields([:id, :status])
        # Enable transaction support
        in_transaction? true
        repo ECommerce.Repo
      end
      
      command :deactivate_customer do
        fields([:id])
        identity_field(:id)

        # A nested `transaction` block is not implemented: the `command` entity
        # declares no nested entities. Use the flat options shown above.
        in_transaction? true
        repo ECommerce.Repo
        transaction_timeout 5000
        transaction_isolation_level :read_committed
      end
    end
  end
end
```

## Command Options

Each command can have the following options:

- `fields`: List of fields the command accepts
- `identity_field`: Field used to identify the aggregate instance
- `autogenerate_handler?`: Whether to generate a command handler (default: true)
- `handler_name`: Custom name for the handler function (default: :handle)
- `action`: Ash action to invoke when handling the command (defaults to command name)
- `command_name`: Override the generated command module name
- `in_transaction?`: Whether to execute the command in a transaction (boolean)
- `repo`: The Ecto repository to use for transactions (atom)
- `transaction_timeout`: The transaction timeout in milliseconds (number)
- `transaction_isolation_level`: The transaction isolation level (atom)

For detailed information about transaction support, see the [Transactions](transactions.html) documentation.

## Generated Command Modules

For each command, AshCommanded generates a command module:

```elixir
defmodule ECommerce.Commands.RegisterCustomer do
  @moduledoc """
  Command for registering a new customer
  """

  @type t :: %__MODULE__{
    id: String.t(),
    email: String.t(),
    name: String.t()
  }

  defstruct [:id, :email, :name]
end
```

## Command Handlers

AshCommanded automatically generates [command handlers](https://hexdocs.pm/commanded/Commanded.Commands.Handler.html) that invoke the corresponding Ash actions:

```elixir
defmodule AshCommanded.Commanded.CommandHandlers.CustomerHandler do
  @behaviour Commanded.Commands.Handler

  def handle(%ECommerce.Commands.RegisterCustomer{} = cmd, _metadata) do
    Ash.run_action(ECommerce.Customer, :register_customer, Map.from_struct(cmd))
  end

  def handle(%ECommerce.Commands.UpdateStatus{} = cmd, _metadata) do
    Ash.run_action(ECommerce.Customer, :update_status, Map.from_struct(cmd))
  end
end
```

Command handlers in Commanded are responsible for validating, authorizing, and processing commands. See the [Commanded documentation on command handlers](https://hexdocs.pm/commanded/commands.html#handling-commands) for more details.
