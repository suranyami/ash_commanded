defmodule AshCommanded.Commanded.Transformers.ProjectionTransformerIntegrationTest do
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

  # Define a test resource with commands, events, and projections
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
      end

      events do
        event :user_registered do
          fields([:id, :email, :name])
        end
      end

      projections do
        projection :user_registered do
          action :create
          changes(%{status: :active})
        end
      end
    end
  end

  describe "projection transformer integration" do
    test "projection modules are generated" do
      # Check projection module was created
      assert Code.ensure_loaded?(
               AshCommanded.Commanded.Transformers.ProjectionTransformerIntegrationTest.Projections.UserRegistered
             )

      # Create alias for convenience
      alias AshCommanded.Commanded.Transformers.ProjectionTransformerIntegrationTest.Projections.UserRegistered

      # Check the module has the correct functions
      assert function_exported?(UserRegistered, :apply, 2)
      assert function_exported?(UserRegistered, :action, 0)

      # Test the action function (simpler test)
      assert UserRegistered.action() == :create

      # Skip the full apply test for now - we need a properly initialized resource
      # which is more complex to set up in tests
      # 
      # We can add more comprehensive tests after we have the base functionality working
    end
  end
end
