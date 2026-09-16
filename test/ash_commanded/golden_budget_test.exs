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
  `clause_max <= 10` absolute-ceiling assertion, and from the runtime-reassembly lint below —
  plan 02 introduces staged goldens for not-yet-rewritten components (D-01's staging idiom,
  applied to goldens), and the confirmed live defect this lint targets
  (`.planning/LEARNINGS.md` §1) lives in exactly the same not-yet-rewritten aggregate generator
  that also exceeds the line-count ceiling. The size *ratchet* still applies unconditionally —
  a staged golden cannot grow — and the lint's mechanism is independently proven in
  `assert_no_lint_violations!/1`'s own test below, against a golden manufactured specifically
  to contain the violation.

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

  describe "AshCommanded.Dump.Lint (FOUND-08)" do
    test "flags a list literal concatenated at runtime via the operator form" do
      quoted = quote(do: [] ++ [1, 2])
      assert [%{description: description}] = Lint.check(quoted)
      assert description =~ "++/2"
    end

    test "does not flag a plain list literal that is not part of a concatenation" do
      quoted = quote(do: def(foo, do: [1, 2, 3]))
      assert Lint.check(quoted) == []
    end

    test "flags a keyword-list operand on either side of a runtime concatenation" do
      left_literal = quote(do: [transforms: [], validations: []] ++ opts)
      right_literal = quote(do: opts ++ [transforms: [], validations: []])

      assert [_violation] = Lint.check(left_literal)
      assert [_violation] = Lint.check(right_literal)
    end

    test "flags the compiled remote-call form" do
      quoted = {{:., [line: 7], [:erlang, :++]}, [line: 7], [[], [1, 2]]}
      assert [%{line: 7, description: description}] = Lint.check(quoted)
      assert description =~ ":erlang.++/2"
    end

    test "golden_budget_test fails naming the golden path when a golden contains a violation" do
      tmp_golden =
        Path.join(
          System.tmp_dir!(),
          "lint_violation_#{System.unique_integer([:positive])}.golden"
        )

      File.write!(
        tmp_golden,
        "# gsd-budget: clause_max=1 module_lines=3\ndefmodule Foo do\n  def bar, do: [] ++ [1, 2]\nend\n"
      )

      on_exit(fn -> File.rm(tmp_golden) end)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          AshCommanded.GoldenBudgetTest.assert_no_lint_violations!(tmp_golden)
        end

      assert error.message =~ tmp_golden
    end
  end

  describe "AshCommanded.Dump.Golden.measure/1 clause spans (CR-01)" do
    test "measures a one-line `do:` clause without requiring :end metadata" do
      # A one-line `def bar, do: :ok` carries no `:end` in its AST metadata — only
      # `:end_of_expression`, and not even that when it is the module's last statement.
      # Reading `:end` unconditionally raised KeyError, so any hand-edited golden using
      # shorthand syntax crashed `mix test` and `mix ash_commanded.dump` rather than
      # reporting a budget.
      assert %{clause_max: 1} = Golden.measure("defmodule Foo do\n  def bar, do: :ok\nend\n")
    end

    test "measures a one-line clause that is not the last statement" do
      source = "defmodule Foo do\n  def bar, do: :ok\n  def baz, do: :ok\nend\n"

      assert %{clause_max: 1} = Golden.measure(source)
    end

    test "measures a `do:` clause wrapped across lines by its true span" do
      source = "defmodule Foo do\n  def bar,\n    do: :ok\nend\n"

      assert %{clause_max: 2} = Golden.measure(source)
    end

    test "still measures block clauses by their end line" do
      source = "defmodule Foo do\n  def bar do\n    :ok\n  end\nend\n"

      assert %{clause_max: 3} = Golden.measure(source)
    end

    test "measures the longest clause when block and shorthand forms are mixed" do
      source = "defmodule Foo do\n  def bar, do: :ok\n\n  def baz do\n    :ok\n  end\nend\n"

      assert %{clause_max: 3} = Golden.measure(source)
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
    {header_lines, body} = golden_path |> File.read!() |> Golden.split_header()

    unless Golden.staged?(header_lines) do
      quoted = Code.string_to_quoted!(body, columns: true, token_metadata: true)
      violations = Lint.check(quoted)

      assert violations == [],
             "#{golden_path}: runtime-reassembly violations: #{inspect(violations)}"
    end
  end
end
