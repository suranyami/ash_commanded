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

## Quarantined for Phase 2 (FOUND-03 / FOUND-04)

- **`test/commanded/transformers/commanded_application_integration_test.exs`** renamed to
  `...exs.phase2-blocked` so ExUnit does not collect it. It fails at COMPILE time, not at test time,
  so `@moduletag` cannot quarantine it — `defmodule TestDomain` runs the transformer as the file
  compiles, before ExUnit evaluates any tag. With the file collected, plain `mix test` aborts and no
  plan in this phase can verify its work.

  **Library defect:** `GenerateCommandedApplication` is a DOMAIN transformer. At
  `generate_commanded_application.ex:72` it creates a module whose body invokes Commanded's `router/1`
  macro, which reads `__registered_commands__/0` from a router generated by `GenerateMainRouterModule`
  — a RESOURCE transformer that has not compiled yet. Raises
  `function ...TestDomain.Router.__registered_commands__/0 is undefined`. This is the Domain/Resource
  compile-order boundary ROADMAP.md assigns to Phase 2 (FOUND-03, FOUND-04).

  **A seventh `Code.ensure_loaded?` fiction, in `test/` rather than `lib/`:** the test file's own
  line ~28 guards the `commanded do application do ... end end` block with
  `Code.ensure_loaded?(Commanded.Application)`. Commanded was not a declared dependency before plan
  01-01, so the guard was always false and this "application integration test" never once exercised
  application generation. D-07 removed six such guards from `lib/`; nobody searched `test/`.
  **Phase 2 should sweep `test/` for the same pattern.**

  **Phase 2 must:** fix the transformer's compile-order dependency, delete the stale
  `Code.ensure_loaded?` guard in the test, restore the `_test.exs` extension, and confirm the file
  genuinely exercises application generation rather than silently skipping it.

  Decision: quarantined on the user's explicit instruction after being told that this re-introduces an
  exclusion in the same phase that D-16 removed all default exclusions. Recorded as a knowing
  exception, not an oversight.

## From Plan 01-06

- **Router generation never fires at all, for any domain, under the current Domain/Resource DSL
  split — a second, more fundamental defect in the same family as FOUND-03/FOUND-04.** Confirmed
  by a live probe (compile a real `Ash.Domain` using `AshCommanded.Commanded.DomainDsl` with a
  resource carrying commands, no `application` section so the compile-order crash below is
  avoided): the command, event and aggregate modules generate correctly, but
  `Code.ensure_loaded?/1` is `false` for both `<Domain>.Router` and `<Prefix>.Router`.

  **Root cause:** `GenerateMainRouterModule.transform/1` and `GenerateDomainRouterModule.transform/1`
  are declared only in `AshCommanded.Commanded.Dsl`'s (resource-level) `transformers:` list.
  Both check `Spark.Dsl.Transformer.get_persisted(dsl_state, :module)` — the module *currently
  being compiled* — against `is_ash_domain?/1` / `is_ash_resource?/1`. Since these transformers
  only ever run while a *resource* is compiling, that persisted `:module` is always the resource,
  never the domain, so `GenerateMainRouterModule`'s domain branch can never fire.
  `AshCommanded.Commanded.DomainDsl` does not list either transformer in its own
  `transformers:` (only `GenerateCommandedApplication`), so there is no path by which a domain's
  own compile ever runs router generation either. `GenerateDomainRouterModule` does correctly
  persist `:command_resource_mappings` onto the *resource's own* dsl_state — but nothing ever
  reads that resource-level state back from a domain's compile (Spark dsl_state is per-module;
  there is no built-in cross-module aggregation), so even completing the domain-side wiring
  would need a domain transformer that explicitly walks `Ash.Domain.Info.resources(domain)` and
  reads `Spark.Dsl.Extension.get_persisted/2` on each already-compiled resource — a structural
  change to the transformer architecture, not a mechanical fix.

  This explains, in part, why `GenerateCommandedApplication`'s own compile-order crash
  (`TestDomain.Router.__registered_commands__/0 is undefined`, quarantined above as
  FOUND-03/FOUND-04) was never caught by any router-level test before this phase: no router
  module has ever existed to compile against, in any configuration, so the crash could only ever
  be reached once *something* (any mechanism) finally produced a router module for a domain
  carrying an `application` section — which never happened until this phase made `:commanded` a
  hard dependency and this plan's own probe went looking.

  **Impact on this plan (01-06, TEST-06/TEST-03):** Task 3 could not dispatch a command through
  "the generated router" as originally planned, because no such module is ever produced.
  `test/commanded/generated_modules_test.exs`'s router-dispatch tests use
  `AshCommanded.TestSupport.WidgetRouter` (in `test/support/commanded_app_case.ex`) — a
  hand-written `Commanded.Commands.Router` wired directly to the DSL's real generated
  `Commands.CreateWidget` and `WidgetAggregate` modules — to prove the underlying TEST-06
  per-test-application-isolation claim and real dispatch through Commanded, substituting for the
  (nonexistent) DSL-generated router. This is a substitution, not a fix; documented as a
  deviation in `01-06-SUMMARY.md`.

  **Phase 2 must:** when fixing FOUND-03/FOUND-04's compile-order boundary, also wire
  `GenerateDomainRouterModule`/`GenerateMainRouterModule` (or equivalents) into
  `AshCommanded.Commanded.DomainDsl`'s own transformer list, reading each declared resource's
  persisted command mappings via `Spark.Dsl.Extension.get_persisted/2` rather than the current
  resource-scoped `Transformer.get_persisted/2` calls, which can never see cross-resource state.

  **Corroborated a second time, later in this same plan:** re-tested the hypothesis that this is
  merely a compile-*ordering* problem (files under `test/support` compile ahead of test files, in
  dependency order — could that resolve it?) by defining an equivalent domain+resource pair
  directly under `test/support/` with a real `application` section. Compiling under `MIX_ENV=dev`
  "succeeded" only because `test/support` (minus `test/support/parity`) is outside `:dev`'s
  `elixirc_paths` and the fixture was silently never compiled; compiling under `MIX_ENV=test`
  (where it IS on the path) crashed with the identical
  `function ...Router.__registered_commands__/0 is undefined` error. File placement does not
  change the outcome — confirms the root cause above is correct: the router is never generated
  for any domain, full stop, not merely generated too late.

  **A related, now-fixed bug surfaced by finally calling the generated application module's
  `child_spec/0` for real** (this plan's rewrite of
  `commanded_application_generator_test.exs` away from mocking `BaseTransformer.create_module/3`
  — see its own moduledoc): `generate_commanded_application.ex`'s `include_supervisor?: true`
  branch called `Supervisor.child_spec({Supervisor, opts}, id: ...)`, which requires the first
  element to itself implement `child_spec/1` — bare `Supervisor` doesn't, so this raised
  `ArgumentError` the instant it was ever actually invoked (never before this session — the old
  test only string-matched the generated AST, never called the function). Fixed to build the
  child-spec map directly. Unrelated to the router-generation defect above; recorded here only
  because it was found via the same investigation.

  **Also fixed in this plan, not deferred:** the suite's last two `:meck` users
  (`commanded_application_generator_test.exs`'s three application-generation tests, and
  `aggregate_generator_test.exs`'s two snapshot-config tests, both mocking
  `AshCommanded.Commanded.Dsl.application/1` or `BaseTransformer.create_module/3`) were removed
  entirely, in response to a real intermittent full-suite failure the coordinator measured (5
  runs, 2 failures, `{:error, {:already_started, pid}}` from `:cover.call/1` inside
  `:meck`'s `backup_original/4` — `:meck.new/2` asks the Erlang coverage server to preserve a
  mocked module's cover state, and `:cover.call/1` starts that server on demand if it isn't
  running; two concurrent `async: true` tests' `:meck.new/2` calls could race to start it, and
  the loser crashed). Both files now build real dsl_state maps (or, for
  `commanded_application_generator_test.exs`, a real hand-defined router — see above) instead of
  mocking anything. `grep -rn ':meck\.\|with_mock' test/` now returns no matches. Verified via 35
  consecutive full-suite runs, 0 failures (was ~40% failure rate before this fix).

- **`AshCommanded.TestSupport.Widget`'s `ets do private? true end` makes Ash-side writes
  invisible across a real Commanded dispatch, and is incompatible with asserting on the
  projected Ash record from outside the dispatching process.** `Ash.DataLayer.Ets`'s `private?`
  scopes the ETS table to the *calling process* (`Process.get({:ash_ets_table, ...})`).
  `aggregate_end_to_end_test.exs` (Plan 01-02) calls `WidgetAggregate.execute/2` directly, so the
  write happens in the test's own process and `Ash.get!/2` afterward sees it. Dispatching the
  same command through a real `Commanded.Application` router instead runs `execute/2` inside the
  aggregate's own registered GenServer process (Commanded's standard one-process-per-aggregate
  design) — a different process than the test — so the private ETS table the write lands in is
  invisible to a subsequent `Ash.get!/2` call from the test process. Confirmed by direct probe
  while writing Task 3's router-dispatch tests. Worked around in `generated_modules_test.exs` by
  asserting on `dispatch(..., returning: :aggregate_state)`'s returned aggregate struct (computed
  and returned synchronously to the caller regardless of which process executed it) instead of
  round-tripping through `Ash.get!/2`. Not fixed here — changing `private?` to `false` would
  affect every other test using this shared fixture and is out of this plan's scope. Flagged for
  whichever future plan needs cross-process Ash-record visibility from a real dispatch path (this
  may simply be inherent to `private?: true` and require a per-test non-private resource
  instead, not a "fix" in the usual sense).

## Signed off

- **`snapshot_adapter.ex` no longer declares `@behaviour Commanded.Aggregates.Aggregate.Snapshotter`
  (deviation from D-07).** D-07 specified making the declaration unconditional once Commanded became
  a hard dependency. Verified against `deps/commanded` 1.4.11 and against Commanded's current
  documentation: no such module exists, and Commanded's real snapshotting is internal
  (`Commanded.Snapshotting`), configured per-aggregate via a plain map with no pluggable adapter
  behaviour. Declaring the behaviour fails `mix compile --warnings-as-errors` with "behaviour does not
  exist". The declaration was removed and the four adapter functions left unchanged.

  D-07 was made on a false premise — the `Code.ensure_loaded?` guard was permanently false, so the
  behaviour was never attached and the compiler never checked those functions against anything. The
  decision only became inspectable once the guard came off.

  **User signed off 2026-09-14** after independently confirming against current Commanded
  documentation. Phase 4 (SNAP-01..03) owns whatever the adapter should conform to instead.
