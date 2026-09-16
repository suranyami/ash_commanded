defmodule AshCommanded.Resource.Verifiers.ValidateEventHandlerEventsTest do
  # First-ever collected test for ValidateEventHandlerEvents (Plan 01-05, Task 3).
  # The previous file at this responsibility, `event_handler_tests.exs`, was named
  # so that `mix test` never collected it (it doesn't match `*_test.exs`) and its
  # only assertions were `Code.ensure_loaded?/1` and
  # `Spark.implements_behaviour?/2` — it never compiled a bad DSL and checked
  # rejection. See the 01-05 SUMMARY for the deletion record.
  #
  # See validate_command_names_test.exs for the full rationale of the
  # `Spark.Test` mechanism used here in place of the plan's literal
  # `Code.compile_string` + `assert_raise` wording, which does not work against
  # this repo's Spark version.
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "event handlers referencing non-existent events" do
    test "compiling a handler that subscribes to an undeclared event raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidEventHandlerEvent
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Resource.Dsl]

            attributes do
              uuid_primary_key :id
            end

            commanded do
              events do
                event :user_registered do
                  fields([:id])
                end
              end

              event_handlers do
                handler :my_handler do
                  events([:not_a_real_event])
                  # Prevents GenerateEventHandlerModules from also running for
                  # this malformed handler: it looks up the event module by
                  # name to build a `%EventModule{}` pattern match, and a
                  # non-existent event name resolves to `nil`, crashing the
                  # transformer before ValidateEventHandlerEvents — the
                  # verifier under test — gets a chance to run.
                  autogenerate?(false)
                end
              end
            end
          end
        end

      assert err.message =~
               ~r/Handler `my_handler` references unknown event\(s\): `not_a_real_event`/
    end

    test "a handler that subscribes only to declared events compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedEventHandlerEvent
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            events do
              event :user_registered do
                fields([:id])
              end
            end

            event_handlers do
              handler :my_handler do
                events([:user_registered])
              end
            end
          end
        end
      end
    end

    test "a resource with an empty event_handlers block compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :EmptyEventHandlersBlockEvents
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Resource.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            event_handlers do
            end
          end
        end
      end
    end
  end
end
