defmodule AshCommanded.SeededViolationsTest do
  @moduledoc """
  Permanent regression coverage for ROADMAP.md Phase 1 success criterion 3: five deliberately
  seeded violations, one per gate, each proven to still trip its gate's real detection logic.

  This is the "regression half" of SC3 — it never puts the tree in a red state, because the
  five fixtures live under `priv/seeded_violations/`, on no `elixirc_paths` entry and swept by
  no `.credo.exs` `included:` glob (asserted directly below). The "literal half" — a one-time
  record of the real `mix check` alias actually failing on each violation and recovering — is
  `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md`.

  Every custom-check assertion below constructs its `Credo.SourceFile` with a filename under
  `lib/` (`to_source_file(body, "lib/...")`) — both `NoRuntimeStringToAst` and
  `NoModuleNameSurgery` guard on `String.starts_with?(filename, "lib/")`, so a source file built
  with Credo's default fixture filename would silently short-circuit every assertion here to an
  empty issue list and this test would pass vacuously.
  """

  use Credo.Test.Case

  alias AshCommanded.CredoChecks.NoModuleNameSurgery
  alias AshCommanded.CredoChecks.NoRuntimeStringToAst
  alias AshCommanded.Dump.Golden
  alias AshCommanded.Dump.Lint

  @fixtures_dir Path.join([File.cwd!(), "priv", "seeded_violations"])

  @expected_fixtures ~w(
    oversized_clause.ex
    oversized_quote.ex
    runtime_reassembly.ex
    string_to_ast.ex
    module_name_surgery.ex
  )

  defp fixture!(name) do
    File.read!(Path.join(@fixtures_dir, name))
  end

  describe "FOUND-06 — oversized clause (AshCommanded.Dump.Golden.measure/1)" do
    test "the oversized_clause fixture's clause span exceeds the 10-line ceiling" do
      measured = "oversized_clause.ex" |> fixture!() |> Golden.measure()

      assert measured.clause_max > 10,
             "expected the seeded clause span to exceed 10 lines, got #{measured.clause_max}"
    end
  end

  describe "FOUND-07 — oversized quote block (Credo.Check.Refactor.LongQuoteBlocks)" do
    test "the oversized_quote fixture produces a LongQuoteBlocks issue at the 40-line ceiling" do
      "oversized_quote.ex"
      |> fixture!()
      |> to_source_file("lib/ash_commanded_sample/oversized_quote.ex")
      |> run_check(Credo.Check.Refactor.LongQuoteBlocks, max_line_count: 40)
      |> assert_issue(fn issue -> assert issue.check == Credo.Check.Refactor.LongQuoteBlocks end)
    end
  end

  describe "FOUND-08 — runtime reassembly (AshCommanded.Dump.Lint)" do
    test "the runtime_reassembly fixture produces at least one lint violation with a line number" do
      violations =
        "runtime_reassembly.ex"
        |> fixture!()
        |> Code.string_to_quoted!(columns: true, token_metadata: true)
        |> Lint.check()

      assert [%{line: line, description: description} | _] = violations
      assert is_integer(line)
      assert description =~ "++/2"
    end
  end

  describe "FOUND-09 — string built and reparsed into AST (AshCommanded.CredoChecks.NoRuntimeStringToAst)" do
    test "the string_to_ast fixture produces an issue naming the called function" do
      "string_to_ast.ex"
      |> fixture!()
      |> to_source_file("lib/ash_commanded_sample/string_to_ast.ex")
      |> run_check(NoRuntimeStringToAst)
      |> assert_issue(fn issue -> assert issue.trigger =~ "string_to_quoted!" end)
    end
  end

  describe "FOUND-10 — module-name surgery (AshCommanded.CredoChecks.NoModuleNameSurgery)" do
    test "the module_name_surgery fixture produces an issue" do
      "module_name_surgery.ex"
      |> fixture!()
      |> to_source_file("lib/ash_commanded_sample/module_name_surgery.ex")
      |> run_check(NoModuleNameSurgery)
      |> assert_issue(fn issue -> assert issue.check == NoModuleNameSurgery end)
    end
  end

  describe "the fixture set itself" do
    test "is exactly the five expected files, so a sixth gate without a fixture fails here" do
      actual =
        @fixtures_dir
        |> Path.join("*.ex")
        |> Path.wildcard()
        |> Enum.map(&Path.basename/1)
        |> Enum.sort()

      assert actual == Enum.sort(@expected_fixtures)
    end
  end
end
