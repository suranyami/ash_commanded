# Transactions

AshCommanded provides transaction support for commands, allowing you to execute commands atomically and ensure consistency across multiple commands or actions.

## Configuring Transactions for Commands

Transactions can be configured at the command level in the `commanded` DSL:

```elixir
defmodule MyApp.Order do
  use Ash.Resource,
    extensions: [AshCommanded.Commanded.Dsl]

  commanded do
    commands do
      # Enable transactions with inline options
      command :create_order do
        fields [:id, :customer_id, :total]
        identity_field :id
        in_transaction? true
        repo MyApp.Repo
        transaction_timeout 5000
        transaction_isolation_level :read_committed
      end

      # The same options on another command
      command :update_order do
        fields [:id, :total]
        identity_field :id
        in_transaction? true
        repo MyApp.Repo
        transaction_timeout 5000
        transaction_isolation_level :read_committed
      end
    end
  end
end
```

## Transaction Options

You can configure the following transaction options:

### Command-level Options

- `in_transaction?`: Whether to execute the command in a transaction (boolean, default: false)
- `repo`: The Ecto repository to use for transactions (atom, required if `in_transaction?` is true)
- `transaction_timeout`: The transaction timeout in milliseconds (number, optional)
- `transaction_isolation_level`: The transaction isolation level (atom, optional)

### Nested Block Not Implemented

A nested `transaction` block inside a `command` is not implemented: the `command` entity
declares no nested entities. Configure transactions with the flat command-level options listed
above (`in_transaction?`, `repo`, `transaction_timeout`, `transaction_isolation_level`), which
the DSL declares and honours.

## Resource-level Default Options

You can also set default transaction options at the resource level:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain

  commanded do
    commands do
      # Default transaction options for all commands in this domain
      default_repo MyApp.Repo
      default_transaction_timeout 10000
      default_transaction_isolation_level :read_committed
    end
  end
end
```

## Multi-Command Transactions

For complex operations that require multiple commands to be executed atomically, AshCommanded provides support for multi-command transactions:

```elixir
# Execute multiple commands in a single transaction
{:ok, results} = AshCommanded.Commanded.Transaction.execute_commands(
  MyApp.Repo,
  [
    %MyApp.Commands.CreateOrder{id: "order-123", customer_id: "cust-456", total: 100.00},
    %MyApp.Commands.CreateOrderItem{order_id: "order-123", product_id: "prod-789", quantity: 2}
  ],
  timeout: 5000,
  isolation_level: :read_committed
)
```

The `execute_commands/3` function:

1. Executes all commands within a single database transaction
2. Returns all results if successful, or rolls back the entire transaction on any error
3. Takes the same transaction options as individual commands

## Error Handling

When a command executed in a transaction encounters an error, the entire transaction is rolled back and an error is returned:

```elixir
{:error, %AshCommanded.Commanded.Error{
  type: :command_error,
  message: "Transaction failed: some error message",
  context: %{error: "..."}
}}
```

The error will include details about which command failed and why, allowing for proper error handling and reporting.

## Transaction Validation

Before executing a command in a transaction, AshCommanded validates:

1. That the specified repository exists and is configured
2. That the repository supports transactions
3. That any required transaction options are properly set

This validation helps prevent runtime errors and ensures that transactions are properly configured.

## Usage Recommendations

Consider using transactions when:

1. A command needs to make changes to multiple resources atomically
2. Multiple commands need to be executed as a single unit of work
3. You need to ensure that either all changes succeed or none do

Transactions are particularly valuable in domains like e-commerce, banking, and inventory management where consistency is critical.
