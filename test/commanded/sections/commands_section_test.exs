defmodule AshCommanded.Commanded.Sections.CommandsSectionTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Sections.CommandsSection

  describe "schema/0" do
    test "returns the commands schema configuration" do
      schema = CommandsSection.schema()

      assert is_list(schema)
      assert Keyword.has_key?(schema, :commands)

      commands_config = Keyword.get(schema, :commands)
      assert Keyword.get(commands_config, :type) == {:list, :any}
      assert Keyword.get(commands_config, :default) == []
      assert is_binary(Keyword.get(commands_config, :doc))
    end
  end

  describe "entities/0" do
    test "returns the command entity configuration" do
      entities = CommandsSection.entities()

      assert is_list(entities)
      assert length(entities) == 1

      [command_entity] = entities
      assert command_entity.name == :command
      assert command_entity.target == AshCommanded.Commanded.Command
      assert command_entity.args == [:name]

      # Check schema field definitions
      schema = command_entity.schema
      assert Keyword.has_key?(schema, :name)
      assert Keyword.has_key?(schema, :fields)
      assert Keyword.has_key?(schema, :identity_field)
      assert Keyword.has_key?(schema, :action)
      assert Keyword.has_key?(schema, :command_name)
      assert Keyword.has_key?(schema, :handler_name)
      assert Keyword.has_key?(schema, :autogenerate_handler?)

      # Check types
      assert Keyword.get(schema[:name], :type) == :atom
      assert Keyword.get(schema[:fields], :type) == {:list, :atom}
      assert Keyword.get(schema[:identity_field], :type) == :atom
      assert Keyword.get(schema[:action], :type) == :atom
      assert Keyword.get(schema[:command_name], :type) == :atom
      assert Keyword.get(schema[:handler_name], :type) == :atom
      assert Keyword.get(schema[:autogenerate_handler?], :type) == :boolean
    end
  end
end
