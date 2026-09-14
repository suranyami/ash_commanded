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
  **Resolved by Plan 01-03** — fixed as part of unguarding this file (see below).

## From Plan 01-03

- **`lib/commanded/transformers/generate_event_handler_modules.ex` `execute_action/2`
  (line ~95, generated code) calls `Ash.run_action(resource_module, action_name, params)` — a
  3-arity function that does not exist.** Verified against `deps/ash/lib/ash.ex`: `Ash.run_action/2`
  takes an `%Ash.ActionInput{}`, not `(resource, action_name, params)`. This is dead-by-construction
  code exposed for the first time by this plan's D-06 removal of `skip_event_handler_module_creation`
  — `test/commanded/event_handlers_dsl_test.exs` is the ONLY test in the suite that exercises
  `event_handlers`, and it never actually dispatches an event through a generated handler (it only
  asserts the DSL parses), so the warning is emitted at compile time but nothing currently calls the
  broken function at runtime. Correctly dispatching an arbitrary named Ash action (which could be a
  generic, create, update, destroy, or read action) requires branching on the action's actual type via
  `Ash.Resource.Info.action/2` — a real design question, not a mechanical guard-removal, and out of
  this plan's scope (mirrors how Plan 01-04 owns `execute_read`/`execute_custom` in
  `command_action_mapper.ex`). Flagged for whichever plan takes ownership of event-handler execution
  correctness.
- **`test/commanded/parameter_transformer_errors_test.exs` — "handles errors in parameter
  transformation" fails** with `ArgumentError: AshCommanded.ParameterTransformerErrorsTest.TestResource
  is not a Spark DSL module`. Root cause: Plan 01-02 deleted `CommandActionMapper.execute_create/4`'s
  `Mix.env() == :test` mock (commit `d28e09a`), so `map_to_action/4` now runs a real
  `Ash.Changeset.new/1` — but this test's own `TestResource` (defined inline at line 85) is a bare
  `defstruct`, not an Ash resource, and was written assuming the mock. Confirmed pre-existing and
  unrelated to this plan: neither `command_action_mapper.ex` nor this test file is in Plan 01-03's
  file list, and the failure is present with none of Plan 01-03's changes applied. Not caught by Plan
  01-02's own verify scope (`command_action_mapper_test.exs` and `aggregate_end_to_end_test.exs` only).
  Flagged for Plan 01-04, which continues work on `command_action_mapper.ex`.
