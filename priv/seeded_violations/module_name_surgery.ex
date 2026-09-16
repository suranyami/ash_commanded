# SEEDED VIOLATION (ROADMAP Phase 1 SC3, FOUND-10) — deliberately invalid, deliberately
# uncompiled. This fixture exists to trip the module-name-surgery gate (rewrite rule 4): a
# module name derived by splitting an existing module's name and reconcatenating it, instead
# of deriving it from `Transformer.get_persisted/2`. Deliberately carries none of
# `AshCommanded.CredoChecks.Exemption`'s named marker comment (see that module for the exact
# literal text) — this is the genuine-defect shape the marker is deliberately reserved for
# NOT covering. Note for anyone editing this file: do not paste the marker's literal text
# into this comment block, even to describe it, or `Exemption.exempted?/2`'s plain
# substring search will silently exempt this fixture and this gate's own regression test
# will pass vacuously. It lives under `priv/seeded_violations/` — on no `elixirc_paths`
# entry and swept by no `.credo.exs` `included:` glob — so it encodes this violation
# permanently without ever compiling or linting. See
# `test/ash_commanded/seeded_violations_test.exs`, the permanent regression test proving
# `AshCommanded.CredoChecks.NoModuleNameSurgery` still flags this shape.
defmodule AshCommanded.SeededViolations.ModuleNameSurgery do
  def rebuild_parent_namespace(existing_module) do
    existing_module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.concat()
  end
end
