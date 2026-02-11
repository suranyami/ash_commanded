defmodule AshCommanded.Commanded.Transformers.AggregateTransformerIntegrationTest do
  use ExUnit.Case, async: false

  # Define a test module with a custom modified version of the DSL extension
  # This avoids conflicts with the mock verifiers in other tests
  defmodule CustomDsl do
    use Spark.Dsl.Extension,
      sections: [AshCommanded.Commanded.Dsl.__sections__()],
      transformers: [
        AshCommanded.Commanded.Transformers.GenerateCommandModules,
        AshCommanded.Commanded.Transformers.GenerateEventModules,
        AshCommanded.Commanded.Transformers.GenerateAggregateModule
      ]
  end

  # Define a test resource with commands and events
  defmodule UserResource do
    use Ash.Resource,
      extensions: [CustomDsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :status, :atom, default: :pending
    end

    commanded do
      commands do
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end

        command :update_email do
          fields([:id, :email])
          identity_field(:id)
        end
      end

      events do
        event :user_registered do
          fields([:id, :email, :name])
        end

        event :email_changed do
          fields([:id, :email])
        end
      end
    end
  end

  describe "aggregate transformer integration" do
    test "DSL correctly processes commands and events" do
      # Extract module information
      resource_module = UserResource
      app_prefix = AshCommanded.Commanded.Transformers.AggregateTransformerIntegrationTest
      resource_name = "UserResource"

      # The expected module name for the aggregate
      _expected_module_name = Module.concat([app_prefix, "#{resource_name}Aggregate"])

      # Verify that the command and event modules were generated
      command_modules = Spark.Dsl.Extension.get_persisted(resource_module, :command_modules, [])
      assert is_list(command_modules)
      assert length(command_modules) == 2

      event_modules = Spark.Dsl.Extension.get_persisted(resource_module, :event_modules, [])
      assert is_list(event_modules)
      assert length(event_modules) == 2

      # Verify that the aggregate module path was stored in the DSL state
      aggregate_module = Spark.Dsl.Extension.get_persisted(resource_module, :aggregate_module)
      assert aggregate_module != nil

      # The aggregate module itself isn't loaded in test mode due to our skip setting,
      # so we can't directly test its functionality

      # Verify our commands were correctly registered
      commands = Spark.Dsl.Extension.get_entities(resource_module, [:commanded, :commands])
      assert length(commands) == 2

      register_cmd = Enum.find(commands, &(&1.name == :register_user))
      assert register_cmd.identity_field == :id
      assert register_cmd.fields == [:id, :email, :name]

      update_cmd = Enum.find(commands, &(&1.name == :update_email))
      assert update_cmd.identity_field == :id
      assert update_cmd.fields == [:id, :email]

      # Verify our events were correctly registered
      events = Spark.Dsl.Extension.get_entities(resource_module, [:commanded, :events])
      assert length(events) == 2

      registered_event = Enum.find(events, &(&1.name == :user_registered))
      assert registered_event.fields == [:id, :email, :name]

      email_event = Enum.find(events, &(&1.name == :email_changed))
      assert email_event.fields == [:id, :email]
    end
  end
end
