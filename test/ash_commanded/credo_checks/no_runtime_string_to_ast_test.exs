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

  describe "run/2 — the renderer's own measurement helpers under lib/ash_commanded/dump/" do
    test "produces no issue, even though the file is under lib/ (found live against golden.ex, 01-03)" do
      """
      defmodule AshCommanded.Dump.SampleGolden do
        def measure(body) do
          Code.string_to_quoted!(body, columns: true, token_metadata: true)
        end
      end
      """
      |> to_source_file("lib/ash_commanded/dump/sample_golden.ex")
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
    test "exactly one standalone marker comment exists across all of lib/" do
      # Counts marker COMMENT LINES, not files containing the marker text. The previous
      # assertion counted files, so a file holding the marker twice counted once and the
      # assertion passed vacuously (see CR-02 and no_module_name_surgery_test.exs).
      count =
        "lib"
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.flat_map(&(&1 |> File.read!() |> String.split("\n")))
        |> Enum.count(&marker_comment_line?/1)

      assert count == 1
    end

    test "a prose mention of the marker inside a doc string is not a marker comment" do
      refute marker_comment_line?(
               "  that shape, and is deliberately exempt via the `# #{Exemption.marker()}` marker"
             )
    end
  end

  defp marker_comment_line?(line) do
    Regex.match?(~r/^\s*#\s*#{Regex.escape(Exemption.marker())}\s*$/, line)
  end
end
