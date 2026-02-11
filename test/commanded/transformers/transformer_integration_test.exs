defmodule AshCommanded.Commanded.Transformers.TransformerIntegrationTest do
  use ExUnit.Case, async: false

  # Define a test module with a custom modified version of the DSL extension
  # This avoids conflicts with the mock verifiers in other tests
  defmodule CustomDsl do
    use Spark.Dsl.Extension,
      sections: [AshCommanded.Commanded.Dsl.__sections__()],
      transformers: [
        AshCommanded.Commanded.Transformers.GenerateCommandModules,
        AshCommanded.Commanded.Transformers.GenerateEventModules,
        AshCommanded.Commanded.Transformers.GenerateProjectionModules
      ]
  end

  # Define a test resource with both commands and events
  defmodule UserResource do
    use Ash.Resource,
      extensions: [CustomDsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
    end

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
    end
  end

  describe "transformer integration" do
    test "both command and event modules are generated" do
      # Check both modules were created
      assert Code.ensure_loaded?(
               AshCommanded.Commanded.Transformers.TransformerIntegrationTest.Commands.RegisterUser
             )

      assert Code.ensure_loaded?(
               AshCommanded.Commanded.Transformers.TransformerIntegrationTest.Events.UserRegistered
             )

      # Create aliases for convenience
      alias AshCommanded.Commanded.Transformers.TransformerIntegrationTest.Commands.RegisterUser
      alias AshCommanded.Commanded.Transformers.TransformerIntegrationTest.Events.UserRegistered

      # Check the modules have the correct structure
      assert function_exported?(RegisterUser, :__struct__, 1)
      assert function_exported?(UserRegistered, :__struct__, 1)

      # Check command struct has the correct fields
      command = struct(RegisterUser, %{id: "123", email: "test@example.com", name: "Test User"})
      assert command.id == "123"
      assert command.email == "test@example.com"
      assert command.name == "Test User"

      # Check event struct has the correct fields
      event = struct(UserRegistered, %{id: "123", email: "test@example.com", name: "Test User"})
      assert event.id == "123"
      assert event.email == "test@example.com"
      assert event.name == "Test User"
    end
  end
end
