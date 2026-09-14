# Deferred Items — Phase 01 Build Integrity

Out-of-scope discoveries logged during plan execution, per the executor's scope-boundary rule.
Not fixed here; recorded so Plan 01-03/01-04 (or later phases) do not rediscover them from scratch.

## From Plan 01-02

- **`test/commanded/transformers/commanded_application_generator_test.exs`** — 4 failing tests
  (`:already_started` `:meck.new(AshCommanded.Commanded.Dsl, ...)` errors). Pre-existing at this
  plan's start (confirmed via `git diff --stat`: neither this test file nor
  `generate_commanded_application.ex` was touched by this plan). Surfaced now because Plan 01-01
  made `:commanded` a hard dependency, so `Code.ensure_loaded?(Commanded.Application)` flips from
  false to true and the dead-by-construction code path these tests exercise now actually runs.
  Matches RESEARCH.md's own disposition for this file ("Rewrite: remove conditionals, add D-15
  unique naming") — out of this plan's file list.
- **`test/commanded/transformers/projector_generator_test.exs`** — 1 failing test
  ("builds correct module AST" — asserts `"init"` appears in generated AST, no longer does).
  Pre-existing at this plan's start; `generate_projector_modules.ex` is not in this plan's file
  list (Plan 01-03 owns the other three guarded transformers).
- **`test/commanded/transformers/commanded_application_integration_test.exs`** — compile error
  (`AshCommanded...TestDomain.Router.__registered_commands__/0 is undefined`). Same root cause as
  above (dead-by-construction conditional now live); not in this plan's file list.

None of the above touch `lib/commanded/transformers/generate_aggregate_module.ex`,
`lib/commanded/command_action_mapper.ex`, or any file this plan's fixture created.

- **`lib/commanded/transformers/generate_projector_modules.ex`** — `mix format --check-formatted`
  reports this file as unformatted. Pre-existing (not modified by this plan); out of this plan's
  file list (Plan 01-03 owns the other three guarded transformers). Confirmed this plan's own
  touched files (`command_action_mapper.ex`, `generate_aggregate_module.ex`, `test/support/*`,
  the two new/rewritten test files) all pass `mix format --check-formatted` individually.
