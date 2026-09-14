defmodule AshCommanded.Commanded.Verifiers.ValidateEventNamesTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "duplicate event names" do
    test "compiling a resource with two events of the same name raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :DuplicateEventNames
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Commanded.Dsl]

            attributes do
              uuid_primary_key :id
            end

            commanded do
              events do
                event :user_registered do
                  fields([:id])
                end

                event :user_registered do
                  fields([:id])
                end
              end
            end
          end
        end

      assert err.message =~ ~r/event names are duplicated/
      assert err.message =~ ":user_registered"
    end

    test "a resource with one well-formed event compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedEventNames
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            events do
              event :user_registered do
                fields([:id])
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
                    :EmptyEventsBlock
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

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
