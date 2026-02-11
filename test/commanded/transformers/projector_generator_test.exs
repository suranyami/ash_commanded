defmodule AshCommanded.Commanded.Transformers.ProjectorGeneratorTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Projection
  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Transformers.GenerateProjectorModules

  describe "projector module generation helpers" do
    test "builds correct module names" do
      # Test module naming
      module_name =
        invoke_private(
          GenerateProjectorModules,
          :build_projector_module,
          ["User", MyApp.Accounts]
        )

      assert module_name == MyApp.Accounts.Projectors.UserProjector
    end

    test "builds correct event projection map" do
      # Create events and projections for testing
      event1 = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      event2 = %Event{
        name: :email_changed,
        fields: [:id, :email]
      }

      projection1 = %Projection{
        name: :activate_user,
        event_name: :user_registered,
        action: :create,
        changes: %{status: :active}
      }

      projection2 = %Projection{
        name: :update_email,
        event_name: :email_changed,
        action: :update,
        changes: %{email: "new@example.com"}
      }

      projection3 = %Projection{
        name: :track_registration,
        event_name: :user_registered,
        action: :create,
        changes: %{registered_at: DateTime.utc_now()}
      }

      result =
        invoke_private(
          GenerateProjectorModules,
          :build_event_projection_map,
          [[projection1, projection2, projection3], [event1, event2]]
        )

      # We should get a map of event names to projections
      assert is_map(result)
      assert Map.has_key?(result, :user_registered)
      assert Map.has_key?(result, :email_changed)

      # The user_registered event should have two projections
      user_reg_projections = result[:user_registered]
      assert length(user_reg_projections) == 2
      assert Enum.any?(user_reg_projections, &(&1.name == :activate_user))
      assert Enum.any?(user_reg_projections, &(&1.name == :track_registration))

      # The email_changed event should have one projection
      email_changed_projections = result[:email_changed]
      assert length(email_changed_projections) == 1
      assert Enum.at(email_changed_projections, 0).name == :update_email
    end

    test "builds correct module AST" do
      # Mock resource module and projections for testing
      resource_module = MyApp.User
      resource_name = "User"

      projection1 = %Projection{
        name: :activate_user,
        event_name: :user_registered,
        action: :create,
        changes: %{status: :active},
        autogenerate?: true
      }

      projection2 = %Projection{
        name: :update_email,
        event_name: :email_changed,
        action: :update,
        changes: %{email: "new@example.com"},
        autogenerate?: true
      }

      # Mock the map of event names to projections
      event_projections = %{
        user_registered: [projection1],
        email_changed: [projection2]
      }

      # Mock generated module maps
      event_modules = %{
        user_registered: MyApp.Events.UserRegistered,
        email_changed: MyApp.Events.EmailChanged
      }

      projection_modules = %{
        activate_user: MyApp.Projections.ActivateUser,
        update_email: MyApp.Projections.UpdateEmail
      }

      # Generate the AST
      ast =
        invoke_private(
          GenerateProjectorModules,
          :build_projector_module_ast,
          [
            resource_module,
            resource_name,
            [projection1, projection2],
            event_projections,
            event_modules,
            projection_modules
          ]
        )

      # The AST should be a complex structure with either Commanded components or stub implementation
      assert is_tuple(ast)

      # Check if the generated AST has a handle function somewhere in its structure
      ast_string = Macro.to_string(ast)

      # Check for expected components
      assert String.contains?(ast_string, "@moduledoc")

      # Check for either Commanded.Event.Handler or our stub implementation
      assert String.contains?(ast_string, "init")

      # Check for handle function presence
      assert String.contains?(ast_string, "def handle")

      # Check for perform_action functions
      assert String.contains?(ast_string, "perform_action")
    end
  end

  # Helper to invoke private functions for testing
  defp invoke_private(module, function, args) do
    apply(module, function, args)
  catch
    :error, :undef -> {:error, "Private function #{function} not accessible"}
  end
end
