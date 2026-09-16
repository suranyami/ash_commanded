defmodule AshCommanded.Resource.Verifiers.ValidateEventFieldsTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "event fields referencing non-existent attributes" do
    test "compiling an event with a field that isn't a resource attribute raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidEventField
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Resource.Dsl]

            attributes do
              uuid_primary_key :id
              attribute :email, :string
            end

            commanded do
              events do
                event :user_registered do
                  fields([:id, :email, :not_a_real_attribute])
                end
              end
            end
          end
        end

      assert err.message =~ ~r/Event `user_registered` has unknown fields/
      assert err.message =~ ":not_a_real_attribute"
    end

    test "an event whose fields are all real resource attributes compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedEventFields
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
            attribute :email, :string
          end

          commanded do
            events do
              event :user_registered do
                fields([:id, :email])
              end
            end
          end
        end
      end
    end

    test "a resource with an empty events block compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :EmptyEventsBlockFields
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            events do
            end
          end
        end
      end
    end
  end
end
