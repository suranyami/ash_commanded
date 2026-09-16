# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Design.TagTODO
#
# `generate_application_module/1`'s complexity, and the `TODO: Add dynamically discovered
# projectors here` at line ~109, are both projector-supervision concerns ROADMAP.md's Phase 5
# ("Projection Expressiveness", FOUND-05) already names: "FOUND-05 replaces the unfinished
# TODO at generate_commanded_application.ex:115 and must not reintroduce the cross-module
# compile deadlock closed in Phase 2." Resolving the TODO here, ahead of that phase's own
# compile-order design work, risks exactly the deadlock that note warns against (D-21).
#
# credo:disable-for-this-file AshCommanded.CredoChecks.NoModuleNameSurgery
# gsd-disable-until-phase: 3 — `application_module_name/1` and `main_router_module_name/1`
# reconstruct the application/router module names from the domain module's own name via
# `Module.split/1` + `Module.concat/1,2` (FOUND-10/rewrite-rule-4). ROADMAP.md Phase 3
# ("Application and Routers") owns this transformer's rewrite and is where this is replaced
# with `Transformer.get_persisted/2`, per D-01. (The pre-existing disables above cite the
# archived roadmap's "Phase 5" — stale per D-02, corrected in plan 05, not here.)
defmodule AshCommanded.Commanded.Transformers.GenerateCommandedApplication do
  @moduledoc """
  Generates a Commanded.Application module based on the configuration in the application section.

  This transformer:
  1. Extracts application configuration from the DSL
  2. Generates a module that uses Commanded.Application
  3. Configures it with the options from the application section
  4. Includes supervision tree integration if specified
  """

  use Spark.Dsl.Transformer

  alias AshCommanded.Commanded.Transformers.BaseTransformer
  alias Spark.Dsl.Transformer

  @doc """
  Transforms the DSL state by adding the generated Commanded application module.

  ## Parameters

  * `dsl` - The DSL state to transform.

  ## Returns

  The transformed DSL state with the generated Commanded application module added.

  ## Examples

      iex> transform(dsl)
      %{dsl | modules: dsl.modules ++ [generated_module_ast]}
  """
  @impl true
  @spec transform(Transformer.t()) :: {:ok, Transformer.t()} | {:error, term()}
  def transform(dsl) do
    # Only generate if this is a domain (has resources)
    case get_domain_resources(dsl) do
      [] ->
        {:ok, dsl}

      _resources ->
        do_transform(dsl)
    end
  end

  @doc false
  @impl true
  def after?(AshCommanded.Commanded.Transformers.GenerateMainRouterModule), do: true
  def after?(_), do: false

  # Private Functions

  defp do_transform(dsl) do
    case application_config = AshCommanded.Commanded.Dsl.application(dsl) do
      nil ->
        {:ok, dsl}

      _config ->
        # When running in Domain context, the current module is the Domain (from DomainDsl)
        domain_module = Transformer.get_persisted(dsl, :module)
        app_module = application_module_name(domain_module, application_config)
        router_module = main_router_module_name(domain_module)

        code =
          generate_application_module(
            app_module,
            router_module,
            application_config
          )

        # Create the module at compile time
        BaseTransformer.create_module(app_module, code, __ENV__)

        # Store a reference to the application module in the DSL state
        updated_dsl = Transformer.persist(dsl, :commanded_application_module, app_module)

        {:ok, updated_dsl}
    end
  end

  defp generate_application_module(app_module, router_module, config) do
    include_supervisor? = Keyword.get(config, :include_supervisor?, false)
    otp_app = Keyword.get(config, :otp_app)
    event_store = Keyword.get(config, :event_store)
    pubsub = Keyword.get(config, :pubsub)
    registry = Keyword.get(config, :registry)

    # Extract snapshotting configuration
    snapshotting_enabled = Keyword.get(config, :snapshotting, false)
    snapshot_threshold = Keyword.get(config, :snapshot_threshold, 100)
    snapshot_version = Keyword.get(config, :snapshot_version, 1)
    snapshot_store = Keyword.get(config, :snapshot_store, nil)

    _snapshot_config =
      if snapshotting_enabled,
        do: [
          threshold: snapshot_threshold,
          snapshot_version: snapshot_version
        ],
        else: []

    supervisor_child_specs =
      if include_supervisor? do
        # Find projector modules that need to be supervised
        # For now, just using a simple supervisor
        quote do
          @impl true
          def child_spec do
            # TODO: Add dynamically discovered projectors here
            #
            # `Supervisor.child_spec/2`'s first argument must be a module (or `{module, arg}`)
            # that itself implements `child_spec/1` — bare `Supervisor` does not (it is not a
            # `use Supervisor`-based child module), so passing `{Supervisor, opts}` here raised
            # `ArgumentError: The module Supervisor was given as a child to a supervisor but it
            # does not implement child_spec/1` the moment this function was ever actually called
            # (never exercised before a real, mocked-free
            # commanded_application_generator_test.exs called it directly). Build the child
            # spec map directly instead — an anonymous `Supervisor.start_link/2` with no
            # children, registered under this application's own name.
            %{
              id: Module.concat(unquote(app_module), Supervisor),
              start:
                {Supervisor, :start_link,
                 [
                   [],
                   [strategy: :one_for_one, name: Module.concat(unquote(app_module), Supervisor)]
                 ]},
              type: :supervisor
            }
          end
        end
      else
        quote do
        end
      end

    # Generate configuration options
    config_lines = []

    config_lines =
      if is_atom(event_store) do
        config_lines ++ [{:event_store, [adapter: event_store]}]
      else
        config_lines ++ [{:event_store, Macro.escape(event_store)}]
      end

    config_lines = config_lines ++ [{:pubsub, pubsub}]
    config_lines = config_lines ++ [{:registry, registry}]

    # Add snapshotting configuration if enabled
    config_lines =
      if snapshotting_enabled do
        snapshot_opts = [
          snapshot_every: snapshot_threshold,
          snapshot_module: AshCommanded.Commanded.SnapshotAdapter
        ]

        config_lines ++ [{:snapshotting, snapshot_opts}]
      else
        config_lines
      end

    # Initialize snapshot store if snapshotting is enabled
    snapshot_init =
      if snapshotting_enabled do
        quote do
          @doc """
          Initializes the snapshot store when the application starts.

          This is called automatically by Commanded during application startup.
          """
          @impl true
          def init do
            # Initialize the default snapshot store or a custom one if provided
            snapshot_store = unquote(snapshot_store) || AshCommanded.Commanded.SnapshotStore

            # Initialize the snapshot store with application configuration
            case snapshot_store.init(%{
                   threshold: unquote(snapshot_threshold),
                   version: unquote(snapshot_version)
                 }) do
              :ok ->
                :ok

              {:error, reason} ->
                require Logger
                Logger.warning("Failed to initialize snapshot store: #{inspect(reason)}")
                :ok
            end

            :ok
          end
        end
      else
        quote do
        end
      end

    quote do
      @moduledoc """
      A Commanded application for managing aggregates and event handlers.

      This module is automatically generated by the AshCommanded extension
      based on the application configuration in the DSL.
      """

      use Commanded.Application,
          [
            otp_app: unquote(otp_app)
          ] ++ unquote(Macro.escape(config_lines))

      router(unquote(router_module))

      unquote(supervisor_child_specs)

      unquote(snapshot_init)
    end
  end

  defp application_module_name(domain_module, config) do
    prefix = Keyword.get(config, :prefix)
    domain_name = domain_module |> Module.split() |> List.last()

    if prefix do
      module_name = Module.concat([prefix, "#{domain_name}Application"])

      if String.starts_with?(to_string(prefix), "Elixir.") do
        module_name
      else
        Module.concat(Elixir, module_name)
      end
    else
      Module.concat(domain_module, "Application")
    end
  end

  defp main_router_module_name(domain_module) do
    if domain_module do
      Module.concat(domain_module, "Router")
    else
      AshCommanded.Router
    end
  end

  defp get_domain_resources(dsl) do
    Spark.Dsl.Extension.get_entities(dsl, [:resources]) || []
  end
end
