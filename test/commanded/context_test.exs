defmodule AshCommanded.Commanded.ContextTest do
  use ExUnit.Case, async: true

  # Deliberately not AshCommanded.TestSupport.Widget: proving :context lands on
  # the real changeset requires a change that copies it onto a persisted
  # attribute, and Widget's create action has none — attaching one there would
  # be an unrelated edit to a fixture other plans in this wave also read.
  # ContextWidget (test/support/context_widget.ex) is the same ETS-backed,
  # dependency-free real-Ash-resource pattern Widget itself uses, with exactly
  # that one addition.
  alias AshCommanded.TestSupport.ContextWidget

  # A plain command struct — map_to_action only needs field access via
  # Map.from_struct/1, scoped to what ContextWidget's create action accepts.
  defmodule ContextCommand do
    @moduledoc false
    defstruct [:id, :name]
  end

  # Define a test module with a custom DSL extension for testing context options
  defmodule CustomDsl do
    use Spark.Dsl.Extension,
      sections: [AshCommanded.Commanded.Dsl.__sections__()]
  end

  # Test resource with commands using different context configurations
  defmodule UserResource do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.ContextTest.CustomDsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
    end

    commanded do
      commands do
        # Command with default context settings
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end

        # Command with custom context options
        command :update_email do
          fields([:id, :email])
          identity_field(:id)

          # Customize context options
          include_aggregate?(false)
          include_metadata?(true)
          context_prefix(:cmd)
        end

        # Command with static context
        command :delete_user do
          fields([:id])
          identity_field(:id)

          # Use static context
          static_context(%{source: :admin_panel, reason: :user_request})
        end
      end
    end
  end

  describe "context propagation" do
    test "verifies default context options are applied" do
      # Get the command entity
      commands = Spark.Dsl.Extension.get_entities(UserResource, [:commanded, :commands])
      register_command = Enum.find(commands, &(&1.name == :register_user))

      # Verify default context options
      assert register_command.include_aggregate? == true
      assert register_command.include_command? == true
      assert register_command.include_metadata? == true
      assert register_command.context_prefix == nil
      assert register_command.static_context == %{}
    end

    test "verifies custom context options are applied" do
      # Get the command entity
      commands = Spark.Dsl.Extension.get_entities(UserResource, [:commanded, :commands])
      update_command = Enum.find(commands, &(&1.name == :update_email))

      # Verify custom context options
      assert update_command.include_aggregate? == false
      assert update_command.include_command? == true
      assert update_command.include_metadata? == true
      assert update_command.context_prefix == :cmd
    end

    test "verifies static context is properly configured" do
      # Get the command entity
      commands = Spark.Dsl.Extension.get_entities(UserResource, [:commanded, :commands])
      delete_command = Enum.find(commands, &(&1.name == :delete_user))

      # Verify static context
      assert delete_command.static_context == %{source: :admin_panel, reason: :user_request}
    end

    test "context is built correctly in command execution" do
      # Mirrors what GenerateAggregateModule's generated execute/2 builds for a
      # command with include_aggregate?: true, include_command?: true,
      # include_metadata?: true, context_prefix: nil,
      # static_context: %{app_version: "1.0.0"} — see generate_aggregate_module.ex.
      aggregate = %{id: nil, name: nil, email: nil}
      metadata = %{user_id: "admin-456", timestamp: DateTime.utc_now()}

      context =
        %{}
        |> Map.put(:aggregate, aggregate)
        |> Map.put(:metadata, metadata)
        |> Map.merge(%{app_version: "1.0.0"})

      id = Ash.UUID.generate()

      # The mapper no longer echoes its opts back — context is only provable by
      # observing where it actually lands: on the real Ash changeset the create
      # action receives, via ContextWidget's context-capturing change.
      assert {:ok, _record} =
               AshCommanded.Commanded.CommandActionMapper.map_to_action(
                 %ContextCommand{id: id, name: "Widget"},
                 ContextWidget,
                 :create,
                 action_type: :create,
                 context: context
               )

      probe = Ash.get!(ContextWidget, id).context_probe

      assert probe =~ "app_version: \"1.0.0\""
      assert probe =~ "aggregate:"
      assert probe =~ "metadata:"
    end

    test "context with prefix is built correctly" do
      # Mirrors context_prefix: :test — aggregate/command keys are prefixed;
      # static context is merged unprefixed, matching generate_aggregate_module.ex.
      aggregate = %{id: nil, name: nil, email: nil}

      context =
        %{}
        |> Map.put(:"test.aggregate", aggregate)
        |> Map.merge(%{app_version: "1.0.0"})

      id = Ash.UUID.generate()

      assert {:ok, _record} =
               AshCommanded.Commanded.CommandActionMapper.map_to_action(
                 %ContextCommand{id: id, name: "Widget"},
                 ContextWidget,
                 :create,
                 action_type: :create,
                 context: context
               )

      probe = Ash.get!(ContextWidget, id).context_probe

      # inspect/1 renders an atom key containing a "." quoted, as "test.aggregate": ...
      assert probe =~ ~s("test.aggregate")
      assert probe =~ "app_version: \"1.0.0\""
    end
  end
end
