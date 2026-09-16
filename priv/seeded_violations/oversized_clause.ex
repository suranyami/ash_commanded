# SEEDED VIOLATION (ROADMAP Phase 1 SC3, FOUND-06) — deliberately invalid, deliberately
# uncompiled. This fixture exists to trip the clause-size gate: a single `def`/`defp` clause
# spanning more than 10 rendered lines, shaped like rendered generator output (per-field
# assignment then a single return) rather than like this transformer's own hand-written
# source. It lives under `priv/seeded_violations/` — on no `elixirc_paths` entry (`mix.exs`)
# and swept by no `.credo.exs` `included:` glob — so it encodes this violation permanently
# without ever compiling or linting. See `test/ash_commanded/seeded_violations_test.exs`,
# the permanent regression test proving `AshCommanded.Dump.Golden.measure/1` (the same
# helper `mix ash_commanded.dump --write`'s ratchet and `golden_budget_test.exs` share)
# still reports this clause's span as exceeding the ceiling.
defmodule AshCommanded.SeededViolations.OversizedClause do
  def execute(%__MODULE__{} = state, command) do
    field_one = command.field_one
    field_two = command.field_two
    field_three = command.field_three
    field_four = command.field_four
    field_five = command.field_five
    field_six = command.field_six
    field_seven = command.field_seven
    field_eight = command.field_eight
    field_nine = command.field_nine

    {:ok,
     %{
       state
       | a: field_one,
         b: field_two,
         c: field_three,
         d: field_four,
         e: field_five,
         f: field_six,
         g: field_seven,
         h: field_eight,
         i: field_nine
     }}
  end
end
