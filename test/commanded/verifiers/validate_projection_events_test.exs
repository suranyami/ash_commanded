defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionEventsTest do
  # Rewritten per Plan 01-05 (D-14/D-17) — see validate_command_names_test.exs for
  # the full rationale of the `Spark.Test` mechanism used here in place of the
  # plan's literal `Code.compile_string` + `assert_raise` wording, which does not
  # work against this repo's Spark version (confirmed empirically, recorded in
  # the 01-05 SUMMARY).
  #
  # Every malformed resource below declares a valid action and a valid `changes`
  # map so that only `ValidateProjectionEvents` — the verifier under test — has
  # anything to reject.
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "projections referencing non-existent events" do
    test "compiling a projection whose event_name matches no declared event raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidProjectionEvent
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
                projection :activate_user do
                  event_name(:not_a_real_event)
                  action :create
                  changes(%{status: :active})
                  # Prevents GenerateProjectorModules from also running for this
                  # malformed projection: it looks up the event module by name to
                  # build a `%EventModule{}` pattern match, and a non-existent
                  # event name resolves to `nil`, crashing the transformer before
                  # ValidateProjectionEvents — the verifier under test — gets a
                  # chance to run. Only the verifier under test should reject
                  # this resource.
                  autogenerate?(false)
                end
              end
            end
          end
        end

      assert err.message =~
               ~r/Projection `activate_user` references unknown event `not_a_real_event`/
    end

    test "a projection whose event_name matches a declared event compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedProjectionEvent
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
                    :EmptyProjectionsBlockEvents
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
