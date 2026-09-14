defmodule AshCommanded.Commanded.Verifiers.ValidateCommandNamesTest do
  # Rewritten per Plan 01-05 (D-14/D-17): the previous version of this file mocked
  # `Spark.Dsl.Verifier`'s own `get_persisted`/`get_entities` accessors and called
  # `ValidateCommandNames.verify/1` directly. That could never fail if the verifier
  # were dropped from `AshCommanded.Commanded.Dsl`'s `verifiers/0` list, because the
  # test never went through real DSL compilation in the first place.
  #
  # This version reaches the verifier the only way a real consumer does: by
  # compiling a resource that uses `AshCommanded.Commanded.Dsl` and observing what
  # the compiler's verifier pipeline actually does with it.
  #
  # IMPORTANT (deviation from this plan's literal D-14 wording, recorded in the
  # 01-05 SUMMARY): D-14 specified `Code.compile_string/1` wrapped in
  # `assert_raise Spark.Error.DslError, ~r/.../`. That mechanism does not work
  # against this repo's actual Spark version (2.7.2) — verifier errors raised
  # inside Spark's `@after_verify` hook are converted to stderr warnings by the
  # framework rather than propagated as exceptions (confirmed empirically: a
  # `Code.compile_string` + `assert_raise` probe against a duplicate-command-name
  # resource printed a warning and left `assert_raise` reporting "nothing was
  # raised"). `Spark.Test` (shipped in this same Spark version, `deps/spark/lib/
  # spark/test.ex`) exists specifically to solve this and says so in its own
  # moduledoc. It is used here instead: `assert_dsl_error/1` registers the test
  # process as Spark's verifier-error collector, defines the malformed resource,
  # and returns the collected `%Spark.Error.DslError{}` for direct assertion —
  # the same real-compilation guarantee D-14 wanted, through the mechanism this
  # Spark version actually supports.
  @moduledoc false
  use ExUnit.Case, async: true

  import Spark.Test

  describe "duplicate command names" do
    test "compiling a resource with two commands of the same name raises Spark.Error.DslError" do
      err =
        assert_dsl_error do
          defmodule Module.concat([
                      :"AshCommandedTest#{System.unique_integer([:positive])}",
                      :DuplicateCommandNames
                    ]) do
            use Ash.Resource,
              domain: nil,
              extensions: [AshCommanded.Commanded.Dsl]

            attributes do
              uuid_primary_key :id
            end

            commanded do
              commands do
                command :register_user do
                  fields([:id])
                end

                command :register_user do
                  fields([:id])
                end
              end
            end
          end
        end

      assert err.message =~ ~r/command names are duplicated/
      assert err.message =~ ":register_user"
    end

    test "a resource with one well-formed command compiles without raising" do
      refute_dsl_errors do
        defmodule Module.concat([
                    :"AshCommandedTest#{System.unique_integer([:positive])}",
                    :WellFormedCommandNames
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

          attributes do
            uuid_primary_key :id
          end

          commanded do
            commands do
              command :register_user do
                fields([:id])
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
                    :EmptyCommandsBlock
                  ]) do
          use Ash.Resource,
            domain: nil,
            extensions: [AshCommanded.Commanded.Dsl]

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
