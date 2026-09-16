# SEEDED VIOLATION (ROADMAP Phase 1 SC3, FOUND-08) — deliberately invalid, deliberately
# uncompiled. This fixture exists to trip the runtime-reassembly gate (rewrite rule 2):
# a compile-time-known keyword list concatenated at runtime via `++/2`, shaped like rendered
# output (the confirmed `:erlang.++` defect class recorded in `.planning/LEARNINGS.md` #1)
# rather than like this transformer's own hand-written source. It lives under
# `priv/seeded_violations/` — on no `elixirc_paths` entry and swept by no `.credo.exs`
# `included:` glob — so it encodes this violation permanently without ever compiling or
# linting. See `test/ash_commanded/seeded_violations_test.exs`, the permanent regression
# test proving `AshCommanded.Dump.Lint.check/1` still reports this concatenation, naming
# its line.
defmodule AshCommanded.SeededViolations.RuntimeReassembly do
  def execute(state, _command) do
    opts = [] ++ [transforms: [], validations: []]
    {:ok, state, opts}
  end
end
