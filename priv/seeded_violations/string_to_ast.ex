# SEEDED VIOLATION (ROADMAP Phase 1 SC3, FOUND-09) — deliberately invalid, deliberately
# uncompiled. This fixture exists to trip the string-to-AST gate (rewrite rule 10): a
# transformer-shaped module that builds AST from an interpolated string via
# `Code.string_to_quoted!/2` instead of constructing it directly with `quote`/`unquote`.
# It lives under `priv/seeded_violations/` — on no `elixirc_paths` entry and swept by no
# `.credo.exs` `included:` glob — so it encodes this violation permanently without ever
# compiling or linting. See `test/ash_commanded/seeded_violations_test.exs`, the permanent
# regression test proving `AshCommanded.CredoChecks.NoRuntimeStringToAst` still flags this
# call, naming the called function.
defmodule AshCommanded.SeededViolations.StringToAst do
  def build_module_ast(module_name) do
    Code.string_to_quoted!("defmodule #{module_name} do\n  def run, do: :ok\nend")
  end
end
