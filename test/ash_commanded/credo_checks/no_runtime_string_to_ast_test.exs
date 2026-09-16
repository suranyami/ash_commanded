defmodule AshCommanded.CredoChecks.NoRuntimeStringToAstTest do
  use Credo.Test.Case

  alias AshCommanded.CredoChecks.Exemption
  alias AshCommanded.CredoChecks.NoRuntimeStringToAst

  describe "run/2 — a call to a string-to-AST function under lib/" do
    test "produces one issue naming the called function" do
      """
      defmodule CredoSampleModule do
        def build(app_module_source) do
          Code.string_to_quoted!(app_module_source)
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/builder.ex")
      |> run_check(NoRuntimeStringToAst)
      |> assert_issue(fn issue ->
        assert issue.trigger == "Code.string_to_quoted!"
        assert issue.message =~ "string_to_quoted!"
      end)
    end

    test "flags the raising and non-raising string_to_quoted forms, eval_string, and compile_string" do
      """
      defmodule CredoSampleModule do
        def a(s), do: Code.string_to_quoted(s)
        def b(s), do: Code.string_to_quoted!(s)
        def c(s), do: Code.eval_string(s)
        def d(s), do: Code.compile_string(s)
      end
      """
      |> to_source_file("lib/ash_commanded_sample/all_forms.ex")
      |> run_check(NoRuntimeStringToAst)
      |> assert_issues(fn issues -> assert Enum.count(issues) == 4 end)
    end
  end

  describe "run/2 — the same call outside lib/" do
    test "produces no issue" do
      """
      defmodule CredoSampleModule do
        def build(app_module_source) do
          Code.string_to_quoted!(app_module_source)
        end
      end
      """
      |> to_source_file("test/support/not_under_lib.ex")
      |> run_check(NoRuntimeStringToAst)
      |> refute_issues()
    end
  end

  describe "run/2 — the named exemption marker" do
    test "suppresses an issue for the one function it precedes, even though the shape is present" do
      """
      defmodule CredoSampleModule do
        # #{Exemption.marker()}
        def build(app_module_source) do
          Code.string_to_quoted!(app_module_source)
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/exempted_builder.ex")
      |> run_check(NoRuntimeStringToAst)
      |> refute_issues()
    end
  end

  describe "the exemption marker's footprint in the real tree" do
    test "appears in exactly one function across all of lib/" do
      count =
        "lib"
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.map(&File.read!/1)
        |> Enum.count(&String.contains?(&1, Exemption.marker()))

      assert count == 1
    end
  end
end
