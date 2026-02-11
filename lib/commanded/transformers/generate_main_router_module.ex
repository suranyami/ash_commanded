defmodule AshCommanded.Commanded.Transformers.GenerateMainRouterModule do
  @moduledoc """
  Generates the main router module that delegates to domain-specific routers.

  This transformer collects all command-resource mappings from the DSL state 
  and generates:

  1. Domain-specific router modules for each domain with commands
  2. A main router module that delegates to these domain routers

  This transformer should run after the domain router transformer has processed all resources.

  ## Example

  ```elixir
  # Domain-specific routers
  defmodule MyApp.Accounts.Router do
    use Commanded.Commands.Router
    
    dispatch [MyApp.Accounts.Commands.RegisterUser],
      to: MyApp.Accounts.UserAggregate,
      identity: :id
  end

  defmodule MyApp.Billing.Router do
    use Commanded.Commands.Router
    
    dispatch [MyApp.Billing.Commands.CreateInvoice],
      to: MyApp.Billing.InvoiceAggregate,
      identity: :id
  end

  # Main router
  defmodule MyApp.Router do
    @moduledoc "Main router for all commands in the application"
    
    use Commanded.Commands.Router
    
    # Forward commands to domain-specific routers
    identify MyApp.Accounts.Commands.RegisterUser, as: :accounts
    forward :accounts, to: MyApp.Accounts.Router
    
    identify MyApp.Billing.Commands.CreateInvoice, as: :billing
    forward :billing, to: MyApp.Billing.Router
    
    # Helper function to dispatch any command
    def dispatch_command(command) do
      __MODULE__.dispatch(command)
    end
  end
  ```

  For simpler applications with a single domain, the main router may directly handle commands:

  ```elixir
  defmodule MyApp.Router do
    use Commanded.Commands.Router
    
    dispatch [MyApp.Commands.RegisterUser, MyApp.Commands.CreateInvoice],
      to: MyApp.UserAggregate,
      identity: :id
  end
  ```
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  alias AshCommanded.Commanded.Transformers.BaseTransformer
  alias AshCommanded.Commanded.Transformers.GenerateDomainRouterModule

  @doc """
  Specifies that this transformer should run after the domain router transformer.
  """
  @impl true
  def after?(GenerateDomainRouterModule), do: true
  def after?(_), do: false

  @doc """
  Transforms the DSL state to generate router modules.

  This transformer will:
  1. Collect command mappings from all resources
  2. Generate domain-specific router modules
  3. Generate the main router module

  ## Examples

      iex> transform(dsl_state)
      {:ok, updated_dsl_state}
  """
  @impl true
  def transform(dsl_state) do
    resource_module = Transformer.get_persisted(dsl_state, :module)

    # Skip if the module isn't an Ash.Domain
    unless is_ash_domain?(resource_module) do
      {:ok, dsl_state}
    else
      # Get all the command-resource mappings from the DSL state
      command_mappings = Transformer.get_persisted(dsl_state, :command_resource_mappings, [])

      # Only proceed if there are command mappings
      if command_mappings == [] do
        {:ok, dsl_state}
      else
        # Group command mappings by domain
        domain_mappings = Enum.group_by(command_mappings, & &1.domain)

        # Generate domain router modules
        domain_routers = generate_domain_routers(domain_mappings)

        # Generate the main router module
        app_prefix = BaseTransformer.get_module_prefix(resource_module)
        main_router_module = build_main_router_module(app_prefix)

        # Create the main router AST and define it
        main_router_ast =
          build_main_router_ast(
            domain_mappings,
            domain_routers,
            command_mappings
          )

        # Skip actual module creation in test environment
        unless Application.get_env(
                 :ash_commanded,
                 :skip_router_module_creation,
                 Mix.env() == :test
               ) do
          # Create the domain router modules
          domain_routers
          |> Enum.each(fn {domain_module, router_ast} ->
            router_module = GenerateDomainRouterModule.build_domain_router_module(domain_module)
            BaseTransformer.create_module(router_module, router_ast, __ENV__)
          end)

          # Create the main router module
          BaseTransformer.create_module(main_router_module, main_router_ast, __ENV__)
        end

        # Store the generated module in DSL state
        updated_dsl_state =
          Transformer.persist(dsl_state, :main_router_module, main_router_module)

        {:ok, updated_dsl_state}
      end
    end
  end

  # Check if module is an Ash.Domain
  defp is_ash_domain?(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :__ash_domain__, 0)
  end

  @doc """
  Builds the module name for the main router.

  ## Examples

      iex> build_main_router_module(MyApp)
      MyApp.Router
  """
  def build_main_router_module(app_prefix) do
    Module.concat([app_prefix, "Router"])
  end

  # Generate the domain router modules
  defp generate_domain_routers(domain_mappings) do
    domain_mappings
    |> Enum.map(fn {domain_module, resource_mappings} ->
      # Group command modules by aggregate and identity field
      aggregate_groups =
        Enum.group_by(
          resource_mappings,
          fn mapping -> {mapping.aggregate, mapping.identity_field} end
        )

      # Generate the router AST
      router_ast = build_domain_router_ast(domain_module, aggregate_groups)

      {domain_module, router_ast}
    end)
  end

  # Build the AST for a domain router
  defp build_domain_router_ast(domain_module, aggregate_groups) do
    # Create a more descriptive moduledoc
    domain_name = domain_module |> Module.split() |> List.last()
    moduledoc = "Router for commands in the #{domain_name} domain"

    # Generate dispatch handlers for each aggregate group
    dispatch_handlers =
      aggregate_groups
      |> Enum.map(fn {{aggregate_module, identity_field}, mappings} ->
        # Get all command modules for this aggregate
        command_modules =
          mappings
          |> Enum.flat_map(fn mapping ->
            mapping.commands
            |> Enum.map(fn command ->
              # Build the full command module name
              resource_prefix = BaseTransformer.get_module_prefix(mapping.resource)
              command_name_str = BaseTransformer.camelize_atom(command.name)
              command_module = Module.concat([resource_prefix, "Commands", command_name_str])

              command_module
            end)
          end)

        # Generate the dispatch handler for this aggregate
        generate_aggregate_dispatch_handler(command_modules, aggregate_module, identity_field)
      end)

    # Check if Commanded is available to determine what to generate
    if Code.ensure_loaded?(Commanded) do
      quote do
        @moduledoc unquote(moduledoc)

        use Commanded.Commands.Router

        # Dispatch handlers for each aggregate
        unquote_splicing(dispatch_handlers)
      end
    else
      # Generate a stub module for testing when Commanded isn't available
      quote do
        @moduledoc unquote(moduledoc)

        # This is a stub implementation for testing
        # In production, this would use Commanded.Commands.Router

        # Stub dispatch function
        def dispatch(command) do
          {:ok, command}
        end
      end
    end
  end

  # Generate a dispatch handler for an aggregate
  defp generate_aggregate_dispatch_handler(command_modules, aggregate_module, identity_field) do
    quote do
      dispatch(unquote(command_modules),
        to: unquote(aggregate_module),
        identity: unquote(identity_field)
      )
    end
  end

  # Build the AST for the main router
  defp build_main_router_ast(domain_mappings, domain_routers, all_command_mappings) do
    # Create a descriptive moduledoc
    moduledoc = "Main router for all commands in the application"

    # Determine if we need to forward to domain routers
    has_multiple_domains = Enum.count(domain_mappings) > 1

    router_body =
      if has_multiple_domains do
        # Generate forward directives for each domain
        forward_directives =
          domain_mappings
          |> Enum.map(fn {domain_module, resource_mappings} ->
            # Get all command modules for this domain
            all_commands =
              resource_mappings
              |> Enum.flat_map(fn mapping -> mapping.commands end)

            # Get the router module for this domain
            domain_router = GenerateDomainRouterModule.build_domain_router_module(domain_module)

            # Generate domain identifier (use the last part of the domain module name)
            domain_name = domain_module |> Module.split() |> List.last() |> String.downcase()
            domain_id = String.to_atom(domain_name)

            # Generate identify directives for commands
            identify_directives =
              all_commands
              |> Enum.map(fn command ->
                # Find the mapping for this command to get the resource module
                mapping =
                  Enum.find(all_command_mappings, fn m ->
                    Enum.any?(m.commands, fn c -> c.name == command.name end)
                  end)

                if mapping do
                  resource_prefix = BaseTransformer.get_module_prefix(mapping.resource)
                  command_name_str = BaseTransformer.camelize_atom(command.name)
                  command_module = Module.concat([resource_prefix, "Commands", command_name_str])

                  quote do
                    identify(unquote(command_module), as: unquote(domain_id))
                  end
                end
              end)
              |> Enum.filter(&(&1 != nil))

            # Generate forward directive for the domain
            identify_directives ++
              [
                quote do
                  forward(unquote(domain_id), to: unquote(domain_router))
                end
              ]
          end)
          |> List.flatten()

        # Helper function for dispatching commands
        helper_function =
          quote do
            @doc """
            Helper function to dispatch any command with snapshot support.

            ## Parameters

            - `command` - The command to dispatch
            - `opts` - Additional options to pass to the dispatcher

            ## Returns

            The result of dispatching the command
            """
            def dispatch_command(command, opts \\ []) do
              # Add snapshot adapter options to command dispatch
              snapshot_opts = AshCommanded.Commanded.SnapshotConfiguration.dispatch_options()
              dispatch_opts = Keyword.merge(snapshot_opts, opts)

              __MODULE__.dispatch(command, dispatch_opts)
            end
          end

        forward_directives ++ [helper_function]
      else
        # For a single domain, include direct dispatch handlers
        case domain_routers do
          [{_domain, router_ast}] ->
            # Extract the dispatch handlers from the domain router AST
            extract_dispatch_handlers(router_ast)

          _ ->
            []
        end
      end

    # Check if Commanded is available to determine what to generate
    if Code.ensure_loaded?(Commanded) do
      quote do
        @moduledoc unquote(moduledoc)

        use Commanded.Commands.Router

        # Router body (forwards or direct dispatches)
        unquote_splicing(router_body)
      end
    else
      # Generate a stub module for testing when Commanded isn't available
      quote do
        @moduledoc unquote(moduledoc)

        # This is a stub implementation for testing
        # In production, this would use Commanded.Commands.Router

        # Stub dispatch function
        def dispatch(command) do
          {:ok, command}
        end

        def dispatch_command(command, _opts \\ []) do
          dispatch(command)
        end
      end
    end
  end

  # Extract dispatch handlers from domain router AST
  defp extract_dispatch_handlers({:__block__, _, block_contents}) do
    block_contents
    |> Enum.filter(fn node ->
      case node do
        {:dispatch, _, _} -> true
        _ -> false
      end
    end)
  end

  defp extract_dispatch_handlers(_) do
    []
  end
end
