defmodule AshCommanded.Commanded.CommandsDslTest do
  use ExUnit.Case, async: true

  defmodule ResourceWithCommands do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :status, :atom, default: :inactive
    end

    commanded do
      commands do
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end

        command :update_email do
          fields([:id, :email])
          command_name(:ChangeUserEmail)
          autogenerate_handler?(false)
        end

        command :deactivate do
          fields([:id])
          action :mark_inactive
          handler_name(:handle_deactivate_user)
        end
      end
    end
  end

  describe "commands DSL" do
    test "resource can define commands" do
      # Just checking that the module compiles successfully
      assert Code.ensure_loaded?(ResourceWithCommands)

      # Access the command DSL configuration
      commands = Spark.Dsl.Extension.get_entities(ResourceWithCommands, [:commanded, :commands])

      # Check that we have the correct number of commands
      assert length(commands) == 3

      # Find commands by name and check their properties
      register_cmd = Enum.find(commands, &(&1.name == :register_user))
      assert register_cmd.fields == [:id, :email, :name]
      assert register_cmd.identity_field == :id
      assert register_cmd.autogenerate_handler? == true

      update_cmd = Enum.find(commands, &(&1.name == :update_email))
      assert update_cmd.command_name == :ChangeUserEmail
      assert update_cmd.autogenerate_handler? == false

      deactivate_cmd = Enum.find(commands, &(&1.name == :deactivate))
      assert deactivate_cmd.action == :mark_inactive
      assert deactivate_cmd.handler_name == :handle_deactivate_user
    end
  end
end
