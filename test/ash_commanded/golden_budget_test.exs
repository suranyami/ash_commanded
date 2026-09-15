defmodule AshCommanded.GoldenBudgetTest do
  @moduledoc """
  Enforces FOUND-06's absolute clause-size ceiling and D-03's per-golden size ratchet, and
  FOUND-08's runtime-reassembly lint, against every committed golden render under
  `test/golden/`.

  Each `.golden` file's own first line is a `# gsd-budget: clause_max=N module_lines=N` header
  declaring what its committed body was measured at. This test parses that header, re-measures
  the committed body, and asserts the declared numbers still match — it never regenerates
  anything, so it is independent of D-12's formatter/version sensitivity (Elixir's *parser* is
  stable across the supported minor range even though its pretty-printer is not). Header
  parsing and size measurement are delegated to `AshCommanded.Dump.Golden`, the same module
  `mix ash_commanded.dump --write` uses, so the mix task and this gate cannot drift in how they
  count.

  A golden whose header carries a `# gsd-staged-until-phase:` marker is exempt from the
  `clause_max <= 10` absolute-ceiling assertion only — plan 02 introduces staged goldens for
  not-yet-rewritten components (D-01's staging idiom, applied to goldens).

  One test is generated per discovered golden file: a `test/golden/**/*.golden` glob that finds
  nothing generates zero tests, which is itself the failure signal that the gate measured
  nothing (T-01-BI-01).
  """

  use ExUnit.Case, async: true

  alias AshCommanded.Dump.Golden
  alias AshCommanded.Dump.Lint

  # The same explicit module list `scripts/compile_parity.sh` checks (D-09) — every module the
  # parity fixture generates must have a committed golden (FOUND-06's corpus requirement).
  @expected_modules [
    "AshCommanded.TestSupport.Parity.WidgetAggregate",
    "AshCommanded.TestSupport.Parity.Commands.CreateWidget",
    "AshCommanded.TestSupport.Parity.Events.WidgetCreated",
    "AshCommanded.TestSupport.Parity.Projections.WidgetCreated",
    "AshCommanded.TestSupport.Parity.Projectors.WidgetProjector",
    "AshCommanded.TestSupport.Parity.EventHandlers.WidgetNotifierHandler"
  ]

  golden_files =
    [File.cwd!(), "test", "golden", "**", "*.golden"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()

  for golden_path <- golden_files do
    @golden_path golden_path
    relative_path = Path.relative_to_cwd(golden_path)

    test "enforces the declared budget for #{relative_path}" do
      AshCommanded.GoldenBudgetTest.assert_within_budget!(@golden_path)
    end

    test "has no runtime-reassembly violations for #{relative_path}" do
      AshCommanded.GoldenBudgetTest.assert_no_lint_violations!(@golden_path)
    end
  end

  test "every module the parity fixture generates has a committed golden (D-09)" do
    for module_name <- @expected_modules do
      matches =
        Path.wildcard(Path.join([File.cwd!(), "test", "golden", "*", "#{module_name}.golden"]))

      assert matches != [],
             "#{module_name}: no committed golden found under test/golden/*/#{module_name}.golden"
    end
  end

  @doc false
  def assert_within_budget!(golden_path) do
    {header_lines, body} = golden_path |> File.read!() |> Golden.split_header()
    budget = Golden.parse_budget!(List.first(header_lines), golden_path)

    unless Golden.staged?(header_lines) do
      assert budget.clause_max <= 10,
             "#{golden_path}: declared clause_max #{budget.clause_max} exceeds FOUND-06's absolute ceiling of 10 lines"
    end

    measured = Golden.measure(body)

    assert measured.clause_max <= budget.clause_max,
           "#{golden_path}: measured clause span #{measured.clause_max} exceeds declared clause_max #{budget.clause_max}"

    assert measured.module_lines <= budget.module_lines,
           "#{golden_path}: measured module_lines #{measured.module_lines} exceeds declared module_lines #{budget.module_lines}"
  end

  @doc false
  def assert_no_lint_violations!(golden_path) do
    {_header_lines, body} = golden_path |> File.read!() |> Golden.split_header()
    quoted = Code.string_to_quoted!(body, columns: true, token_metadata: true)

    violations = Lint.check(quoted)

    assert violations == [],
           "#{golden_path}: runtime-reassembly violations: #{inspect(violations)}"
  end
end
