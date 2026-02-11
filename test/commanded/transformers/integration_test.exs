defmodule AshCommanded.Commanded.Transformers.IntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateCommandModules

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

  describe "command module generation" do
    defmodule TestResource do
      use Ash.Resource,
        extensions: [CustomDsl],
        domain: nil

      attributes do
        uuid_primary_key :id
        attribute :email, :string
        attribute :name, :string
      end

      commanded do
        commands do
          command :register_user do
            fields([:id, :email, :name])
            identity_field(:id)
          end
        end
      end
    end

    test "transformer is properly configured" do
      # Verify the transformer function exists
      assert function_exported?(GenerateCommandModules, :transform, 1)
    end
  end
end
