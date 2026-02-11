defmodule AshCommanded.Commanded.Transaction do
  @moduledoc """
  Transaction support for command execution in AshCommanded.

  This module provides functionality for wrapping command execution inside database
  transactions, ensuring atomicity of operations across multiple resources and commands.

  Transactions can be used in two ways:
  1. Automatically based on command configuration in the DSL
  2. Manually by wrapping command execution in a transaction block

  ## Features
  - Supports single command transactions
  - Supports multi-command transactions
  - Integrates with Ash Repository transactions
  - Handles rollback on error
  - Provides transaction options (timeout, isolation level)
  """

  defstruct __spark_metadata__: nil

  alias AshCommanded.Commanded.Error
  alias Ecto.Multi

  @typedoc """
  Options for transaction execution
  """
  @type transaction_options :: [
          timeout: pos_integer(),
          isolation_level: :read_committed | :repeatable_read | :serializable
        ]

  @typedoc """
  Function that will be executed within a transaction
  """
  @type transaction_function :: (-> any())

  @doc """
  Executes a function within a transaction.

  ## Parameters
  * `repo` - The repository to use for the transaction
  * `fun` - The function to execute inside the transaction
  * `opts` - Transaction options

  ## Options
  * `:timeout` - Transaction timeout in milliseconds
  * `:isolation_level` - Transaction isolation level (`:read_committed`, `:repeatable_read`, or `:serializable`)

  ## Returns
  * `{:ok, result}` - The result of the function, if the transaction succeeded
  * `{:error, reason}` - The error that caused the transaction to roll back

  ## Examples

      iex> AshCommanded.Commanded.Transaction.run(MyApp.Repo, fn ->
      ...>   # Execute commands or actions
      ...>   AshCommanded.Commanded.CommandActionMapper.map_to_action(command, resource, action)
      ...> end)
      {:ok, %MyApp.User{id: "123", name: "John"}}
  """
  @spec run(module(), transaction_function(), transaction_options()) ::
          {:ok, any()} | {:error, any()}
  def run(repo, fun, opts \\ []) when is_function(fun, 0) do
    transaction_opts = Keyword.take(opts, [:timeout, :isolation_level])

    try do
      repo.transaction(fun, transaction_opts)
    rescue
      error ->
        {:error,
         Error.dispatch_error("Transaction failed: #{Exception.message(error)}",
           context: %{error: inspect(error)}
         )}
    end
  end

  @doc """
  Executes multiple commands in a single transaction.

  ## Parameters
  * `repo` - The repository to use for the transaction
  * `commands` - List of commands to execute, each with resource and action
  * `opts` - Transaction options

  ## Command Structure
  Each command in the list should be a map with these keys:
  * `:command` - The command struct to execute
  * `:resource` - The resource module
  * `:action` - The action name (atom)
  * `:opts` - (Optional) Command-specific options

  ## Returns
  * `{:ok, result_map}` - Map of results from all commands
  * `{:error, failed_operation, failed_value, changes_so_far}` - Error information

  ## Examples

      iex> AshCommanded.Commanded.Transaction.execute_commands(MyApp.Repo, [
      ...>   %{command: create_user_cmd, resource: MyApp.User, action: :create},
      ...>   %{command: create_profile_cmd, resource: MyApp.Profile, action: :create}
      ...> ])
      {:ok, %{create_user: %MyApp.User{...}, create_profile: %MyApp.Profile{...}}}
  """
  @spec execute_commands(module(), [map()], transaction_options()) ::
          {:ok, map()} | {:error, any(), any(), %{atom() => any()}}
  def execute_commands(repo, commands, opts \\ []) when is_list(commands) do
    multi =
      Enum.reduce(commands, Multi.new(), fn command_spec, multi ->
        operation_name = command_name_to_operation(command_spec)

        Multi.run(multi, operation_name, fn _repo, _changes ->
          AshCommanded.Commanded.CommandActionMapper.map_to_action(
            command_spec.command,
            command_spec.resource,
            command_spec.action,
            command_spec[:opts] || []
          )
        end)
      end)

    transaction_opts = Keyword.take(opts, [:timeout, :isolation_level])

    try do
      repo.transaction(multi, transaction_opts)
    rescue
      error ->
        {:error, :transaction_error,
         Error.dispatch_error("Transaction failed: #{Exception.message(error)}",
           context: %{error: inspect(error)}
         ), %{}}
    end
  end

  @doc """
  Checks whether a repository supports transactions.

  ## Parameters
  * `repo` - The repository to check

  ## Returns
  * `true` - If the repository supports transactions
  * `false` - If the repository does not support transactions

  ## Examples

      iex> AshCommanded.Commanded.Transaction.supports_transactions?(MyApp.Repo)
      true

      iex> AshCommanded.Commanded.Transaction.supports_transactions?(MyApp.InMemoryRepo)
      false
  """
  @spec supports_transactions?(module()) :: boolean()
  def supports_transactions?(repo) do
    Code.ensure_loaded?(repo) && function_exported?(repo, :transaction, 2)
  end

  # Converts a command spec to an operation name for the Multi
  defp command_name_to_operation(command_spec) do
    command = command_spec.command
    command_module = command.__struct__

    if command_spec[:name] do
      # Use provided name if available
      command_spec.name
    else
      # Otherwise derive from command module name
      command_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()
    end
  end
end
