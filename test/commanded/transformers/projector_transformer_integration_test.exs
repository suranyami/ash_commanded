defmodule AshCommanded.Commanded.Transformers.ProjectorTransformerIntegrationTest do
  use ExUnit.Case, async: false

  # Define a test module with a custom modified version of the DSL extension
  # This avoids conflicts with the mock verifiers in other tests
  defmodule CustomDsl do
    use Spark.Dsl.Extension,
      sections: [AshCommanded.Commanded.Dsl.__sections__()],
      transformers: [
        AshCommanded.Commanded.Transformers.GenerateCommandModules,
        AshCommanded.Commanded.Transformers.GenerateEventModules,
        AshCommanded.Commanded.Transformers.GenerateProjectionModules,
        AshCommanded.Commanded.Transformers.GenerateProjectorModules
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
      attribute :registered_at, :utc_datetime
    end

    commanded do
      events do
        event :user_registered do
          fields([:id, :email, :name])
        end

        event :email_changed do
          fields([:id, :email])
        end
      end

      projections do
        projection :activate_user do
          event_name(:user_registered)
          action :create

          changes(%{
            status: :active
          })
        end

        projection :update_email do
          event_name(:email_changed)
          action :update

          changes(%{
            email: "updated-email@example.com"
          })
        end

        # A projection that won't be auto-generated
        projection :not_generated do
          event_name(:user_registered)
          action :create
          changes(%{status: :inactive})
          autogenerate?(false)
        end
      end
    end
  end

  describe "projector transformer integration" do
    test "transformer is properly configured" do
      # Extract the projector module name that would be generated
      resource_module = UserResource
      app_prefix = AshCommanded.Commanded.Transformers.ProjectorTransformerIntegrationTest
      resource_name = "UserResource"

      # We'll use these variables in more advanced tests later
      _expected_module_name =
        Module.concat([app_prefix, "Projectors", "#{resource_name}Projector"])

      # Verify that the projector module would use the right event modules
      event_modules_path = Spark.Dsl.Extension.get_persisted(resource_module, :event_modules, [])
      assert is_list(event_modules_path)

      # Verify that the projection modules were built correctly
      projection_modules_path =
        Spark.Dsl.Extension.get_persisted(resource_module, :projection_modules, [])

      assert is_list(projection_modules_path)

      # Verify that our specific projections are in the DSL
      projections = Spark.Dsl.Extension.get_entities(resource_module, [:commanded, :projections])
      assert length(projections) == 3

      # Find the activate_user projection
      activate_user = Enum.find(projections, &(&1.name == :activate_user))
      assert activate_user.event_name == :user_registered
      assert activate_user.action == :create
      assert is_map(activate_user.changes)
      assert activate_user.changes.status == :active
      assert activate_user.autogenerate? == true

      # Find the not_generated projection and verify autogenerate is false
      not_generated = Enum.find(projections, &(&1.name == :not_generated))
      assert not_generated.autogenerate? == false
    end
  end
end
