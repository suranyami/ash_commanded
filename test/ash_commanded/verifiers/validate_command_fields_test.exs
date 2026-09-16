defmodule AshCommanded.Resource.Verifiers.ValidateCommandFieldsTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "command fields referencing non-existent attributes" do
    test "compiling a command with a field that isn't a resource attribute raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidCommandField
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Resource.Dsl]

            attributes do
              uuid_primary_key :id
              attribute :email, :string
            end

            commanded do
              commands do
                command :register_user do
                  fields([:id, :email, :not_a_real_attribute])
                end
              end
            end
          end
        end

      assert err.message =~ ~r/Command `register_user` has unknown fields/
      assert err.message =~ ":not_a_real_attribute"
    end

    test "a command whose fields are all real resource attributes compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedCommandFields
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
            attribute :email, :string
          end

          commanded do
            commands do
              command :register_user do
                fields([:id, :email])
              end
            end
          end
        end
      end
    end

    test "a resource with an empty commands block compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :EmptyCommandsBlockFields
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            commands do
            end
          end
        end
      end
    end
  end
end
