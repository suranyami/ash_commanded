defmodule AshCommanded.Commanded.CommandActionMappingTest do
  use ExUnit.Case, async: true

  defmodule ResourceWithEnhancedCommands do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :first_name, :string
      attribute :last_name, :string
      attribute :status, :atom, default: :inactive
      attribute :created_at, :utc_datetime
      attribute :updated_at, :utc_datetime
    end

    commanded do
      commands do
        # Basic command without advanced mapping
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end

        # Command with action type specified
        command :update_profile do
          fields([:id, :name, :email])
          action :update_user_profile
          action_type(:update)
        end

        # Command with parameter mapping (map)
        command :split_name do
          fields([:id, :name])
          action :update_split_name
          param_mapping(%{name: :full_name})
        end

        # Command with parameter mapping (function)
        command :register_with_timestamp do
          fields([:id, :email, :name])
          action :create_with_timestamp
          action_type(:create)

          param_mapping(
            quote(
              do: fn params ->
                Map.put(params, :created_at, DateTime.utc_now())
              end
            )
          )
        end
      end

      events do
        event :user_registered do
          fields([:id, :email, :name])
        end

        event :profile_updated do
          fields([:id, :name, :email])
        end

        event :name_split do
          fields([:id, :name])
        end

        event :user_registered_with_timestamp do
          fields([:id, :email, :name, :created_at])
        end
      end
    end
  end

  describe "enhanced command action mapping" do
    test "resource can define commands with enhanced action mappings" do
      # Just checking that the module compiles successfully
      assert Code.ensure_loaded?(ResourceWithEnhancedCommands)

      # Access the command DSL configuration
      commands =
        Spark.Dsl.Extension.get_entities(ResourceWithEnhancedCommands, [:commanded, :commands])

      # Check that we have the correct number of commands
      assert length(commands) == 4

      # Find commands by name and check their properties
      register_cmd = Enum.find(commands, &(&1.name == :register_user))
      assert register_cmd.fields == [:id, :email, :name]
      assert register_cmd.identity_field == :id
      assert register_cmd.action_type == nil
      assert register_cmd.param_mapping == nil

      update_cmd = Enum.find(commands, &(&1.name == :update_profile))
      assert update_cmd.action == :update_user_profile
      assert update_cmd.action_type == :update
      assert update_cmd.param_mapping == nil

      split_cmd = Enum.find(commands, &(&1.name == :split_name))
      assert split_cmd.action == :update_split_name
      assert split_cmd.param_mapping == %{name: :full_name}

      timestamp_cmd = Enum.find(commands, &(&1.name == :register_with_timestamp))
      assert timestamp_cmd.action == :create_with_timestamp
      assert timestamp_cmd.action_type == :create
      assert Macro.to_string(timestamp_cmd.param_mapping) =~ "fn params ->"

      assert Macro.to_string(timestamp_cmd.param_mapping) =~
               "Map.put(params, :created_at, DateTime.utc_now())"
    end
  end
end
