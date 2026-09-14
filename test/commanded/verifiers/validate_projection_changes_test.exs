defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionChangesTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  #
  # Every malformed resource below declares a valid action and a valid, matching
  # event so that only `ValidateProjectionChanges` — the verifier under test —
  # has anything to reject.
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "projection changes referencing non-existent attributes" do
    test "compiling a projection whose changes map references a non-attribute raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidProjectionChanges
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Commanded.Dsl]

            attributes do
              uuid_primary_key :id
              attribute :status, :atom
            end

            commanded do
              events do
                event :user_registered do
                  fields([:id])
                end
              end

              projections do
                projection :user_registered do
                  event_name(:user_registered)
                  action :create
                  changes(%{status: :active, not_a_real_attribute: "value"})
                end
              end
            end
          end
        end

      assert err.message =~ ~r/Projection `user_registered` has unknown attributes/
      assert err.message =~ ":not_a_real_attribute"
    end

    test "a projection whose changes map references only real attributes compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedProjectionChanges
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

          attributes do
            uuid_primary_key :id
            attribute :status, :atom
          end

          commanded do
            events do
              event :user_registered do
                fields([:id])
              end
            end

            projections do
              projection :user_registered do
                event_name(:user_registered)
                action :create
                changes(%{status: :active})
              end
            end
          end
        end
      end
    end

    test "a resource with an empty projections block compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :EmptyProjectionsBlockChanges
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            projections do
            end
          end
        end
      end
    end
  end
end
