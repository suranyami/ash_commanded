defmodule AshCommanded.Commanded.Transformers.CollectTransactionOptions do
  @moduledoc """
  Collects transaction options from the DSL and applies them to commands.
  
  This transformer processes both:
  1. Command-level transaction options within each command
  2. Resource-level default transaction options
  3. Transaction entity blocks within commands
  
  The collected options are stored in each command's data structure for later use
  during command execution.
  """
  
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  # alias AshCommanded.Commanded.Command
  
  @doc """
  Transforms the DSL state to collect transaction options.
  """
  @impl true
  def transform(dsl_state) do
    # Get global default options
    default_repo = Transformer.get_option(dsl_state, [:commanded, :commands], :default_repo)
    default_timeout = Transformer.get_option(dsl_state, [:commanded, :commands], :default_transaction_timeout)
    default_isolation = Transformer.get_option(dsl_state, [:commanded, :commands], :default_transaction_isolation_level)
    
    # Collect commands and augment with transaction options
    commands = 
      Transformer.get_entities(dsl_state, [:commanded, :commands])
      |> Enum.map(fn command -> 
        # Process transaction entity options
        transaction_entity = Transformer.get_entities(command, [:transaction])
        
        # Apply transaction options from the entity if it exists
        command = 
          if transaction_entity && !Enum.empty?(transaction_entity) do
            transaction_opts = List.first(transaction_entity)
            
            # Extract options
            enabled? = Map.get(transaction_opts, :enabled?, true)
            repo = Map.get(transaction_opts, :repo)
            timeout = Map.get(transaction_opts, :timeout)
            isolation_level = Map.get(transaction_opts, :isolation_level)
            
            # Apply them to the command
            %{command | 
              in_transaction?: enabled?,
              repo: repo || command.repo,
              transaction_timeout: timeout || command.transaction_timeout,
              transaction_isolation_level: isolation_level || command.transaction_isolation_level
            }
          else
            command
          end
        
        # Apply defaults for any nil values
        %{command | 
          repo: command.repo || default_repo,
          transaction_timeout: command.transaction_timeout || default_timeout,
          transaction_isolation_level: command.transaction_isolation_level || default_isolation
        }
      end)
    
    # Replace the original commands with the updated ones
    updated_dsl_state =
      Enum.reduce(commands, dsl_state, fn command, acc_dsl_state ->
        Transformer.replace_entity(
          acc_dsl_state,
          [:commanded, :commands],
          command,
          fn existing_command -> existing_command.name == command.name end
        )
      end)

    {:ok, updated_dsl_state}
  end
end