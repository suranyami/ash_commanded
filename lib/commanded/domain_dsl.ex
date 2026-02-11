defmodule AshCommanded.Commanded.DomainDsl do
  @moduledoc """
  Domain-level DSL extension for AshCommanded that adds the `commanded` application section to Ash.Domain.

  This extension allows you to configure the Commanded application (event store, pubsub, etc.)
  on your Ash.Domain. When present, it generates a Commanded.Application module at compile time.

  ## Usage

  Add this extension to any Ash.Domain that uses resources with the Commanded resource extension:

      defmodule MyApp.Domain do
        use Ash.Domain,
          extensions: [AshCommanded.Commanded.DomainDsl]

        resources do
          resource MyApp.User
        end

        commanded do
          application do
            otp_app :my_app
            event_store Commanded.EventStore.Adapters.EventStore
            pubsub :local
            registry :local
            include_supervisor? true
          end
        end
      end

  This will generate `MyApp.Domain.Application` (or a custom name if you use the `prefix` option).
  """

  # Import the Resource DSL so the Domain has the `commanded` macro in scope.
  # The `commanded do application do ... end` block is processed by Commanded.Dsl,
  # which stores config at [:commanded, :application] for our transformer to read.
  use Spark.Dsl.Extension,
    sections: [],
    imports: [AshCommanded.Commanded.Dsl],
    transformers: [
      AshCommanded.Commanded.Transformers.GenerateCommandedApplication
    ]
end
