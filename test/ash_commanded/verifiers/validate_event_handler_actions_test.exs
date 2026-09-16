defmodule AshCommanded.Resource.Verifiers.ValidateEventHandlerActionsTest do
  # First-ever collected test for ValidateEventHandlerActions (Plan 01-05, Task 3).
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

  describe "event handlers with invalid actions" do
    test "compiling a handler with an atom action outside the valid set raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :InvalidEventHandlerAction
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
                  action :not_a_real_action
                end
              end
            end
          end
        end

      assert err.message =~
               ~r/Handler `my_handler` specifies potentially invalid action `not_a_real_action`/
    end

    test "a handler using a common valid action compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedEventHandlerAction
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
                action :create
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
                    :EmptyEventHandlersBlockActions
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
