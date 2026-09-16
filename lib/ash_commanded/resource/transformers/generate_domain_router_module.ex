# credo:disable-for-this-file Credo.Check.Refactor.Nesting
# gsd-disable-until-phase: 3 — router-generation transformer nesting is exactly the
# compile-order boundary ROADMAP.md's current Phase 3 ("Application and Routers", APP-02)
# owns: router generation never fires under the current Domain/Resource DSL split (see
# PROJECT.md's Falsified section), and Phase 3 rewrites this transformer's control flow to
# fix it. (Re-pointed 2026-09-16, plan 05, D-02 — this disable previously cited the archived
# 13-phase roadmap's "Phase 2".)
#
# Router-generation transformer nesting is exactly the compile-order boundary
# ROADMAP.md's Phase 2 ("Deterministic Generation and Compile-Time Rejection", FOUND-03/
# FOUND-04) already schedules to rework, per `.planning/phases/01-build-integrity/
# deferred-items.md`'s "From Plan 01-06" entry (router generation never fires under the
# current Domain/Resource DSL split — Phase 2 rewrites this transformer's control flow to
# fix it). Reducing nesting here now would be redone once that rewrite lands (D-21).
#
# credo:disable-for-this-file AshCommanded.CredoChecks.NoModuleNameSurgery
# gsd-disable-until-phase: 3 — `build_domain_router_module/1` reconstructs a domain router
# module name from an existing module name via `Module.split/1` + `Module.concat/1,2`
# (FOUND-10/rewrite-rule-4). ROADMAP.md Phase 3 ("Application and Routers") owns this
# transformer's rewrite and is where this is replaced with `Transformer.get_persisted/2`, per
# D-01. (The pre-existing disable above cites the archived roadmap's "Phase 2" — stale per
# D-02, corrected in plan 05, not here.)
defmodule AshCommanded.Resource.Transformers.GenerateDomainRouterModule do
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
  alias AshCommanded.Resource.Transformers.GenerateAggregateModule
  alias AshCommanded.Resource.Transformers.GenerateCommandModules
  alias Spark.Dsl.Transformer

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
    case ash_resource?(resource_module) do
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
  defp ash_resource?(module) do
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
