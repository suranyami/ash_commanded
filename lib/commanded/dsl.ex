defmodule AshCommanded.Commanded.Dsl do
  @moduledoc """
  The DSL extension for using Commanded with Ash resources.

  This extension provides the ability to define commands, events, projections, and event handlers using Ash resources,
  and integrates with Commanded to provide CQRS and Event Sourcing patterns.

  ## Usage

  ```elixir
  defmodule MyApp.User do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl]
      
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

  alias AshCommanded.Commanded.Sections.CommandsSection

  @commands_section %Spark.Dsl.Section{
    name: :commands,
    describe: "Define commands that trigger state changes in the resource",
    schema: CommandsSection.schema(),
    entities: CommandsSection.entities(),
    imports: []
  }

  alias AshCommanded.Commanded.Sections.EventsSection

  @events_section %Spark.Dsl.Section{
    name: :events,
    describe: "Define events that are emitted by commands",
    schema: EventsSection.schema(),
    entities: EventsSection.entities(),
    imports: []
  }

  alias AshCommanded.Commanded.Sections.ProjectionsSection

  @projections_section %Spark.Dsl.Section{
    name: :projections,
    describe: "Define how events affect the resource state",
    schema: ProjectionsSection.schema(),
    entities: ProjectionsSection.entities(),
    imports: []
  }

  alias AshCommanded.Commanded.Sections.EventHandlersSection

  @event_handlers_section %Spark.Dsl.Section{
    name: :event_handlers,
    describe: "Define general purpose handlers that respond to events",
    schema: EventHandlersSection.schema(),
    entities: EventHandlersSection.entities(),
    imports: []
  }

  alias AshCommanded.Commanded.Sections.ApplicationSection

  @application_section %Spark.Dsl.Section{
    name: :application,
    describe:
      "Configure the Commanded application (use on your Domain via AshCommanded.Commanded.DomainDsl)",
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
      AshCommanded.Commanded.Transformers.CollectParameterTransforms,
      AshCommanded.Commanded.Transformers.CollectParameterValidations,
      AshCommanded.Commanded.Transformers.CollectTransactionOptions,

      # Generate modules
      AshCommanded.Commanded.Transformers.GenerateCommandModules,
      AshCommanded.Commanded.Transformers.GenerateEventModules,
      AshCommanded.Commanded.Transformers.GenerateProjectionModules,
      AshCommanded.Commanded.Transformers.GenerateProjectorModules,
      AshCommanded.Commanded.Transformers.GenerateEventHandlerModules,
      AshCommanded.Commanded.Transformers.GenerateAggregateModule,
      AshCommanded.Commanded.Transformers.GenerateDomainRouterModule,
      AshCommanded.Commanded.Transformers.GenerateMainRouterModule
    ],
    verifiers: [
      AshCommanded.Commanded.Verifiers.ValidateCommandFields,
      AshCommanded.Commanded.Verifiers.ValidateCommandNames,
      AshCommanded.Commanded.Verifiers.ValidateEventFields,
      AshCommanded.Commanded.Verifiers.ValidateEventNames,
      AshCommanded.Commanded.Verifiers.ValidateProjectionEvents,
      AshCommanded.Commanded.Verifiers.ValidateProjectionActions,
      AshCommanded.Commanded.Verifiers.ValidateProjectionChanges,
      AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents,
      AshCommanded.Commanded.Verifiers.ValidateEventHandlerActions
    ]

  @doc """
  Determine if a resource uses the `commanded` extension.

  ## Examples

      iex> AshCommanded.Commanded.Dsl.extension?(SomeResource)
      true
      
      iex> AshCommanded.Commanded.Dsl.extension?(OtherResource)
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
  def __sections__() do
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
    opts = Spark.Dsl.Extension.get_opt(dsl, [:commanded, :application], nil, nil)

    case opts do
      nil -> nil
      opts -> opts
    end
  end
end
