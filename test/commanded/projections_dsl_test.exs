defmodule AshCommanded.Commanded.ProjectionsDslTest do
  use ExUnit.Case, async: true

  defmodule ResourceWithProjections do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :status, :atom, default: :inactive
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

        event :user_deactivated do
          fields([:id])
        end
      end

      projections do
        projection :user_registered do
          event_name(:user_registered)
          action :create

          changes(%{
            status: :active,
            registered_at: &DateTime.utc_now/0
          })
        end

        projection :email_changed do
          event_name(:email_changed)
          action :update

          changes(fn event ->
            %{
              email: event.email
            }
          end)
        end

        projection :user_deactivated do
          event_name(:user_deactivated)
          action :update
          changes(%{status: :inactive})
          autogenerate?(false)
        end
      end
    end
  end

  describe "projections DSL" do
    test "resource can define projections" do
      # Just checking that the module compiles successfully
      assert Code.ensure_loaded?(ResourceWithProjections)

      # Access the projection DSL configuration
      projections =
        Spark.Dsl.Extension.get_entities(ResourceWithProjections, [:commanded, :projections])

      # Check that we have the correct number of projections
      assert length(projections) == 3

      # Find projections by name and check their properties
      register_proj = Enum.find(projections, &(&1.name == :user_registered))
      assert register_proj.event_name == :user_registered
      assert register_proj.action == :create
      assert is_map(register_proj.changes)
      assert Map.get(register_proj.changes, :status) == :active
      assert is_function(Map.get(register_proj.changes, :registered_at), 0)
      assert register_proj.autogenerate? == true

      email_proj = Enum.find(projections, &(&1.name == :email_changed))
      assert email_proj.event_name == :email_changed
      assert email_proj.action == :update
      assert is_function(email_proj.changes, 1)

      deactivate_proj = Enum.find(projections, &(&1.name == :user_deactivated))
      assert deactivate_proj.event_name == :user_deactivated
      assert deactivate_proj.action == :update
      assert deactivate_proj.changes == %{status: :inactive}
      assert deactivate_proj.autogenerate? == false
    end
  end
end
