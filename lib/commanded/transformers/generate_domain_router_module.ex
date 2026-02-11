defmodule AshCommanded.Commanded.Transformers.GenerateDomainRouterModule do
  @moduledoc """
  Generates a domain-specific router module based on the commands defined in a domain's resources.

  For each Ash.Domain containing resources with commands, this transformer will generate 
  a domain router module that:

  1. Defines dispatch functions for all commands in that domain
  2. Routes commands to the appropriate aggregate

  This transformer should run after the command and aggregate module transformers.

  ## Example

  Given a domain with resources that have commands, this transformer will generate:

  ```elixir
  defmodule MyApp.Accounts.Router do
    @moduledoc "Router for commands in the Accounts domain"
    
    use Commanded.Commands.Router
    
    # Register User commands
    dispatch [MyApp.Accounts.Commands.RegisterUser, MyApp.Accounts.Commands.UpdateEmail],
      to: MyApp.Accounts.UserAggregate,
      identity: :id
      
    # Register Account commands
    dispatch [MyApp.Accounts.Commands.CreateAccount, MyApp.Accounts.Commands.CloseAccount],
      to: MyApp.Accounts.AccountAggregate,
      identity: :id
  end
  ```
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  alias AshCommanded.Commanded.Transformers.GenerateCommandModules
  alias AshCommanded.Commanded.Transformers.GenerateAggregateModule

  @doc """
  Specifies that this transformer should run after the command and aggregate module transformers.
  """
  @impl true
  def after?(GenerateCommandModules), do: true
  def after?(GenerateAggregateModule), do: true
  def after?(_), do: false

  @doc """
  Transforms the DSL state to generate a domain router module.

  ## Examples

      iex> transform(dsl_state)
      {:ok, updated_dsl_state}
  """
  @impl true
  def transform(dsl_state) do
    resource_module = Transformer.get_persisted(dsl_state, :module)

    # Only process if this is an Ash.Resource
    case is_ash_resource?(resource_module) do
      false ->
        {:ok, dsl_state}

      true ->
        commands = Transformer.get_entities(dsl_state, [:commanded, :commands])

        # Only proceed if there are commands defined
        case commands do
          [] ->
            {:ok, dsl_state}

          _commands ->
            # Get the domain module for this resource
            domain_module = get_domain_module(resource_module)

            # Skip if no domain is associated with this resource
            if domain_module == nil do
              {:ok, dsl_state}
            else
              # Get the domain router module name
              domain_router_module = build_domain_router_module(domain_module)

              # Store the command-resource-aggregate mapping in the DSL state
              # This will be used by the main router transformer to build the full router
              command_mappings =
                Transformer.get_persisted(dsl_state, :command_resource_mappings, [])

              aggregate_module = Transformer.get_persisted(dsl_state, :aggregate_module)

              # Get identity field for commands (default to :id if not specified)
              identity_field =
                case List.first(commands) do
                  nil -> :id
                  command -> command.identity_field || :id
                end

              # Update the command mappings with the new resource
              updated_mappings =
                command_mappings ++
                  [
                    %{
                      resource: resource_module,
                      domain: domain_module,
                      domain_router: domain_router_module,
                      aggregate: aggregate_module,
                      identity_field: identity_field,
                      commands: commands
                    }
                  ]

              # Store the updated mappings
              updated_dsl_state =
                Transformer.persist(dsl_state, :command_resource_mappings, updated_mappings)

              # Also store a reference to the domain router
              updated_dsl_state =
                Transformer.persist(
                  updated_dsl_state,
                  :domain_router_module,
                  domain_router_module
                )

              {:ok, updated_dsl_state}
            end
        end
    end
  end

  # Check if module is an Ash.Resource
  defp is_ash_resource?(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :__ash_resource__, 0)
  end

  # Get the domain module for a resource
  defp get_domain_module(resource_module) do
    if function_exported?(resource_module, :__ash_domain__, 0) do
      resource_module.__ash_domain__()
    else
      nil
    end
  end

  @doc """
  Builds the module name for a domain router.

  ## Examples

      iex> build_domain_router_module(MyApp.Accounts)
      MyApp.Accounts.Router
  """
  def build_domain_router_module(domain_module) do
    Module.concat([domain_module, "Router"])
  end
end
