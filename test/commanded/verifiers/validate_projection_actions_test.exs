defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionActionsTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  #
  # Every malformed resource below declares a valid, matching event and a valid
  # `changes` map so that only `ValidateProjectionActions` — the verifier under
  # test — has anything to reject. Without that scaffolding, `ValidateProjectionEvents`
  # or `ValidateProjectionChanges` would also fire on the same resource and the
  # test would not isolate the verifier it claims to exercise.
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "projections with invalid actions" do
    test "compiling a projection with an action outside the valid set raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidProjectionAction
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
                  action :not_a_real_action
                  changes(%{status: :active})
                end
              end
            end
          end
        end

      assert err.message =~
               ~r/Projection `user_registered` specifies potentially invalid action `not_a_real_action`/
    end

    test "a projection with a valid action compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedProjectionAction
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
                    :EmptyProjectionsBlockActions
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
