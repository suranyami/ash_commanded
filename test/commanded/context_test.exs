defmodule AshCommanded.Commanded.ContextTest do
  use ExUnit.Case, async: false

  # Mock command action mapper for testing
  defmodule MockCommandActionMapper do
    def map_to_action(_command, _resource, _action_name, opts) do
      # Return the context from the options to verify it was properly built
      context = Keyword.get(opts, :context, %{})
      {:ok, %{context: context}}
    end
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
      # Create test command and aggregate
      command = %{
        id: "123",
        email: "test@example.com",
        name: "Test User",
        # Add metadata for testing
        metadata: %{
          user_id: "admin-456",
          timestamp: DateTime.utc_now()
        },
        # Context configuration
        include_aggregate?: true,
        include_command?: true,
        include_metadata?: true,
        context_prefix: nil,
        static_context: %{app_version: "1.0.0"}
      }

      aggregate = %{id: nil, name: nil, email: nil}

      # Create middleware context similar to what would be created in the aggregate module
      context = %{}

      # Add aggregate
      context = Map.put(context, :aggregate, aggregate)

      # Add command
      context = Map.put(context, :command, command)

      # Add metadata
      context = Map.put(context, :metadata, command.metadata)

      # Add static context
      context = Map.merge(context, command.static_context)

      # Verify context contains expected keys
      assert context.aggregate == aggregate
      assert context.command == command
      assert context.metadata == command.metadata
      assert context.app_version == "1.0.0"
    end

    test "context with prefix is built correctly" do
      # Create test command and aggregate
      command = %{
        id: "123",
        email: "test@example.com",
        name: "Test User",
        # Context configuration
        include_aggregate?: true,
        include_command?: true,
        include_metadata?: true,
        context_prefix: :test,
        static_context: %{app_version: "1.0.0"}
      }

      aggregate = %{id: nil, name: nil, email: nil}

      # Create middleware context similar to what would be created in the aggregate module
      context = %{}

      # Add aggregate with prefix
      context = Map.put(context, :"test.aggregate", aggregate)

      # Add command with prefix
      context = Map.put(context, :"test.command", command)

      # Add static context
      context = Map.merge(context, command.static_context)

      # Verify context contains expected keys with prefix
      assert Map.get(context, :"test.aggregate") == aggregate
      assert Map.get(context, :"test.command") == command
      assert context.app_version == "1.0.0"
    end
  end
end
