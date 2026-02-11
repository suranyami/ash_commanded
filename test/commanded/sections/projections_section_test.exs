defmodule AshCommanded.Commanded.Sections.ProjectionsSectionTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Sections.ProjectionsSection

  describe "schema/0" do
    test "returns the projections schema configuration" do
      schema = ProjectionsSection.schema()

      assert is_list(schema)
      assert Keyword.has_key?(schema, :projections)

      projections_config = Keyword.get(schema, :projections)
      assert Keyword.get(projections_config, :type) == {:list, :any}
      assert Keyword.get(projections_config, :default) == []
      assert is_binary(Keyword.get(projections_config, :doc))
    end
  end

  describe "entities/0" do
    test "returns the projection entity configuration" do
      entities = ProjectionsSection.entities()

      assert is_list(entities)
      assert length(entities) == 1

      [projection_entity] = entities
      assert projection_entity.name == :projection
      assert projection_entity.target == AshCommanded.Commanded.Projection
      assert projection_entity.args == [:name]

      # Check schema field definitions
      schema = projection_entity.schema
      assert Keyword.has_key?(schema, :name)
      assert Keyword.has_key?(schema, :event_name)
      assert Keyword.has_key?(schema, :action)
      assert Keyword.has_key?(schema, :changes)
      assert Keyword.has_key?(schema, :autogenerate?)

      # Check types
      assert Keyword.get(schema[:name], :type) == :atom
      assert Keyword.get(schema[:event_name], :type) == :atom
      assert Keyword.get(schema[:action], :type) == :atom
      assert Keyword.get(schema[:changes], :type) == {:or, [:map, :quoted]}
      assert Keyword.get(schema[:autogenerate?], :type) == :boolean
    end
  end
end
