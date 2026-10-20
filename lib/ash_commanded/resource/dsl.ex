defmodule AshCommanded.Resource.Dsl do
  @moduledoc """
  The DSL extension for using Commanded with Ash resources.

  This extension provides the ability to define commands, events, projections, and event handlers using Ash resources,
  and integrates with Commanded to provide CQRS and Event Sourcing patterns.

  ## Usage

  ```elixir
  defmodule MyApp.User do
    use Ash.Resource,
      extensions: [AshCommanded.Resource.Dsl]
      
    commanded do
      commands do
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end
      end
      
      events do
        event :user_registered do
          fields([:id, :email, :name])
        end
      end
      
      projections do
        projection :user_registered do
          changes(%{status: :active})
        end
      end
      
      event_handlers do
        handler :user_registered_notification do
          events [:user_registered]
          action fn event, _metadata ->
            MyApp.Notifications.send_welcome_email(event.email)
            :ok
          end
        end
      end
    end
  end
  ```
  """

  require Logger

  alias AshCommanded.Resource.Sections.CommandsSection

  @commands_section %Spark.Dsl.Section{
    name: :commands,
    describe: "Define commands that trigger state changes in the resource",
    schema: CommandsSection.schema(),
    entities: CommandsSection.entities(),
    imports: []
  }

  alias AshCommanded.Resource.Sections.EventsSection

  @events_section %Spark.Dsl.Section{
    name: :events,
    describe: "Define events that are emitted by commands",
    schema: EventsSection.schema(),
    entities: EventsSection.entities(),
    imports: []
  }

  alias AshCommanded.Resource.Sections.ProjectionsSection

  @projections_section %Spark.Dsl.Section{
    name: :projections,
    describe: "Define how events affect the resource state",
    schema: ProjectionsSection.schema(),
    entities: ProjectionsSection.entities(),
    imports: []
  }

  alias AshCommanded.Resource.Sections.EventHandlersSection

  @event_handlers_section %Spark.Dsl.Section{
    name: :event_handlers,
    describe: "Define general purpose handlers that respond to events",
    schema: EventHandlersSection.schema(),
    entities: EventHandlersSection.entities(),
    imports: []
  }

  alias AshCommanded.Resource.Sections.ApplicationSection

  @application_section %Spark.Dsl.Section{
    name: :application,
    describe:
      "Configure the Commanded application (use on your Domain via AshCommanded.Domain.Dsl)",
    schema: ApplicationSection.schema(),
    entities: ApplicationSection.entities(),
    imports: []
  }

  # Top-level section that contains all other sections
  @commanded_section %Spark.Dsl.Section{
    name: :commanded,
    describe: "Configure CQRS and Event Sourcing with Commanded",
    sections: [
      @commands_section,
      @events_section,
      @projections_section,
      @event_handlers_section,
      @application_section
    ]
  }

  # The main extension
  use Spark.Dsl.Extension,
    sections: [@commanded_section],
    transformers: [
      # Collect options from DSL
      AshCommanded.Resource.Transformers.CollectTransactionOptions,

      # Generate modules
      AshCommanded.Resource.Transformers.GenerateCommandModules,
      AshCommanded.Resource.Transformers.GenerateEventModules,
      AshCommanded.Resource.Transformers.GenerateProjectionModules,
      AshCommanded.Resource.Transformers.GenerateProjectorModules,
      AshCommanded.Resource.Transformers.GenerateEventHandlerModules,
      AshCommanded.Resource.Transformers.GenerateAggregateModule,
      AshCommanded.Resource.Transformers.GenerateDomainRouterModule,
      AshCommanded.Resource.Transformers.GenerateMainRouterModule,
      AshCommanded.Domain.Transformers.GenerateCommandedApplication
    ],
    verifiers: [
      AshCommanded.Resource.Verifiers.ValidateCommandFields,
      AshCommanded.Resource.Verifiers.ValidateCommandNames,
      AshCommanded.Resource.Verifiers.ValidateEventFields,
      AshCommanded.Resource.Verifiers.ValidateEventNames,
      AshCommanded.Resource.Verifiers.ValidateProjectionEvents,
      AshCommanded.Resource.Verifiers.ValidateProjectionActions,
      AshCommanded.Resource.Verifiers.ValidateProjectionChanges,
      AshCommanded.Resource.Verifiers.ValidateEventHandlerEvents,
      AshCommanded.Resource.Verifiers.ValidateEventHandlerActions
    ]

  @doc """
  Determine if a resource uses the `commanded` extension.

  ## Examples

      iex> AshCommanded.Resource.Dsl.extension?(SomeResource)
      true
      
      iex> AshCommanded.Resource.Dsl.extension?(OtherResource)
      false
  """
  @spec extension?(Ash.Resource.t()) :: boolean()
  def extension?(resource) do
    extensions = Spark.extensions(resource)
    __MODULE__ in extensions
  end

  @doc """
  Return the section definitions for use in custom DSL extensions.

  This is used in tests to create custom DSL extensions without verifiers.
  """
  @spec __sections__() :: Spark.Dsl.Section.t()
  def __sections__ do
    @commanded_section
  end

  @doc """
  Get the application configuration from the DSL.

  ## Parameters

  * `dsl` - The DSL state.

  ## Returns

  A keyword list of application configuration options, or nil if no application configuration is defined.

  ## Examples

      iex> application(dsl)
      [otp_app: :my_app, event_store: Commanded.EventStore.Adapters.InMemory]
      
      iex> application(dsl_without_app_config)
      nil
  """
  @spec application(Spark.Dsl.t()) :: keyword() | nil
  def application(dsl) do
    # Use :otp_app (a required field) as the sentinel — if nil, the section was not configured.
    case Spark.Dsl.Extension.get_opt(dsl, [:commanded, :application], :otp_app, nil) do
      nil ->
        nil

      _ ->
        get = fn key, default ->
          Spark.Dsl.Extension.get_opt(dsl, [:commanded, :application], key, default)
        end

        [
          otp_app: get.(:otp_app, nil),
          event_store: get.(:event_store, nil),
          pubsub: get.(:pubsub, :local),
          registry: get.(:registry, :local),
          include_supervisor?: get.(:include_supervisor?, false),
          prefix: get.(:prefix, nil),
          snapshotting: get.(:snapshotting, false),
          snapshot_threshold: get.(:snapshot_threshold, 100),
          snapshot_version: get.(:snapshot_version, 1),
          snapshot_store: get.(:snapshot_store, nil)
        ]
    end
  end
end
