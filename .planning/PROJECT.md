# AshCommanded

## What This Is

AshCommanded is an Elixir library that brings CQRS and Event Sourcing to the Ash Framework
declaratively. It is a Spark DSL extension: you describe commands, events, aggregate behaviour
and projections inside an Ash resource, and the library generates the Commanded modules —
command structs, event structs, aggregates, projectors, routers and the Commanded application —
that would otherwise be written by hand, one file at a time.

This project completes a library that was abandoned by its original author with structural pieces
missing, brings it to production quality, and then migrates the `core` application's entire
event-sourced codebase onto it. David is now a maintainer of the upstream repository
(`accountex-org/ash_commanded`) with rights to merge, triage issues and publish to hex.pm, so the
work lands upstream rather than in a private fork.

## Core Value

`core`'s five event-sourced domains run in production on AshCommanded. No lesser proof counts —
a library for removing event-sourcing boilerplate is only credible if it carries a real
event-sourced system.

## Current Milestone: v0.3 Library Rewrite

**Goal:** Rewrite the generation layer component by component, so that every generated module is
thin wiring over hand-written runtime modules — verified by rendering the actual output and
approving it, not by reading the generator.

**Target features:**
- Foundation: a DSL-output renderer (`mix ash_commanded.dump`), golden renders diffed in CI,
  `usage_rules` + AGENTS.md for idiomatic Elixir and testing, custom Credo checks enforcing the
  generation anti-patterns, and an Elixir/OTP CI matrix
- Commands, events and application rewritten first — the cheap components, where the
  render-and-approve methodology gets proven
- Aggregates and projections next, opening with the question the audit surfaced:
  what is `AshCommanded.Aggregate.__using__/1`?
- Routers, event handlers and process managers, including the cross-module state problem that
  makes router generation fail today
- Declarative event versioning, snapshots re-targeted at Commanded's real internals, middleware
  and transaction coordination

**Method (per component):** propose the DSL → write a usage example → build the transformer →
**render the generated output and get human approval** → iterate → persisters and verifiers →
comprehensive tests, suite green.

**Not in this milestone:** `core`'s five-domain migration and the 1.0 publish. Both move to the
next milestone, planned against a DSL that by then actually exists.

## Context

**Why this exists.** `core` has accumulated 163 event-sourcing modules totalling ~6,398 LOC across
five domains — roughly 29% of its 22,380-line `lib` tree — and the volume of files, directories and
near-identical modules has become a drag on working in the codebase. Repetition at that scale is the
textbook smell a DSL exists to remove.

**Measured surface of `core`'s event-sourced code (2026-09-11):**

| Kind | Files | LOC | Character |
|------|-------|-----|-----------|
| Commands | 64 | 505 | Plain structs, ~8 LOC each — near-total boilerplate |
| Events | 68 | 548 | Structs, `@derive Jason.Encoder`, some `Commanded.Event.Upcaster` impls |
| Aggregates | 13 | 1,822 | Genuine invariants mixed with dispatch plumbing |
| Projectors | 18 | 3,523 | Mostly real logic; the heaviest category |
| **Total** | **163** | **6,398** | Across `data`, `identity`, `integration`, `schema_definition`, `workflow` |

The win is asymmetric and worth stating plainly: 132 of 163 files (commands + events) are almost
pure boilerplate but only 1,053 lines. The remaining 5,345 lines carry real business logic that a
DSL can frame but not delete. Expect a dramatic reduction in file and module count and a more
modest reduction in total lines — which is the right trade, because file/module sprawl is the
stated pain.

**Structural gaps found during initial investigation:**

1. **Domain vs Resource DSL split.** The Commanded *application* is a per-domain singleton (one
   router, one event store, one supervisor) and cannot coherently be declared on a resource. Work
   is already in flight on branch `fix-application-generation` separating
   `AshCommanded.Commanded.Dsl` (targets `Ash.Resource`) from `AshCommanded.Commanded.DomainDsl`
   (targets `Ash.Domain`).
2. **No event versioning whatsoever.** `core` relies on `Commanded.Event.Upcaster` to evolve events
   across schema changes (e.g. `Core.Identity.Events.OrganisationRegistered` drops removed fields on
   replay). A search for `Upcaster`/`upcast` across ash_commanded returns nothing. For a library
   whose subject is an append-only log, this is a first-class absence.
3. **No vocabulary for aggregate invariants or non-attribute state.** `core`'s aggregates encode
   business rules as pattern-matched guards (`%__MODULE__{id: nil}` → already-created error;
   `status: :suspended` → reject update) and hold state that is not a resource attribute
   (`members: %{}`). `GenerateAggregateModule` generates execute/apply pairs from command→event
   mappings and has no way to express either.
4. **No end-to-end example.** There is no runnable application demonstrating the library across a
   full command → event → projection → read-model cycle.
5. **No documented testing story.** Nothing shows a consumer how to test a system built this way.
6. **Contrived tests.** Coverage looks healthy by file count, but tests largely assert that
   transformers *ran* (module exists, struct has fields) rather than that DSL misuse is *rejected*.
   Unhappy paths are barely exercised — `test/commanded/verifiers/event_handler_tests.exs` only
   checks that the verifier modules load.

**Documentation drift.** `CLAUDE.md` documents verifiers `ValidateCommandActions`,
`ValidateCommandHandlers` and `ValidateCommandNameConflict`. None of the three exist in
`lib/commanded/verifiers/`. Treat existing documentation as aspirational until verified.

**Known debt (from `.planning/codebase/CONCERNS.md`), all in scope:**

- `:commanded` and `:event_store` are not declared in `mix.exs` despite generated code depending on them
- `IO.puts`/`IO.inspect` in production paths (`snapshot_store.ex:111`, `middleware/base_middleware.ex:18,25,31`)
- `GenerateAggregateModule` is 861 lines spanning command execution, event application and snapshots
- `CommandActionMapper` is 640 lines spanning mapping, transformation, validation, transactions and error handling
- `Error` module is 514 lines
- `generate_commanded_application.ex:115` — projector auto-discovery is an unfinished TODO
- Snapshot store is ETS-only: lost on VM restart, unusable across nodes, not production-ready
- Generated command structs carry no validation independent of middleware

## Requirements

### Validated

<!-- Shipped and confirmed by execution, not by reading. -->

**Build integrity (Phase 01, 2026-09-14)**

- ✓ A test suite capable of failing — 176 tests, 0 failures, stable across 45+ consecutive
  full-suite runs, zero mocking
- ✓ Blocking quality gates — `mix check` = format + Credo (strict) + Dialyzer + Sobelow + test,
  with `.credo.exs` and `.dialyzer_ignore.exs` checked in
- ✓ Cross-environment visibility of generated code — `test/support/parity/` on the `:dev`
  elixirc path plus `scripts/compile_parity.sh`
- ✓ `:commanded` declared as a hard dependency; six `Code.ensure_loaded?` fictions removed from `lib/`
- ✓ Context threaded through `for_action`/`for_read` so declarative changes actually receive it
- ✓ `Ash.Query.for_read(:by_id)` corrected to `:read` in `command_action_mapper.ex`

### Falsified

<!-- Previously assumed working from reading the code; disproved by execution in Phase 01.
     Recorded because the roadmap must not assume them. Full detail: .planning/LEARNINGS.md §3. -->

- ✗ **Domain and main router generation** — never fires for any domain, in any configuration.
  Both transformers are declared only on the resource extension and test a persisted `:module`
  that is always the resource, never the domain. Corroborated twice, including from a fixture
  under `test/support/` so compile order is not the variable.
- ✗ **Commanded application generation** — raises `__registered_commands__/0 is undefined`: a
  domain transformer invokes Commanded's `router/1` against a router the resource transformer has
  not produced. Its integration test is quarantined as `...exs.phase2-blocked`.
- ✗ **Snapshot pluggable adapter interface** — `Commanded.Aggregates.Aggregate.Snapshotter` has
  never existed in any Commanded version. The `@behaviour` sat behind a permanently-false guard,
  so the compiler never checked the four adapter functions against anything. Commanded's real
  snapshotting is internal (`Commanded.Snapshotting`), configured per-aggregate via a plain map.
- ✗ **Event-handler action dispatch** — generated code called `Ash.run_action/3`, which does not
  exist. Fixed in 01-07. Still open: `generate_projector_modules.ex:359` calls
  `Ash.run_action(changeset, action)` — arity 2 exists so it compiles with no warning, but the
  arguments match neither clause. Latent, no compile signal.
- ✗ **"Nine compile-time verifiers"** — `CLAUDE.md` documents three
  (`ValidateCommandActions`, `ValidateCommandHandlers`, `ValidateCommandNameConflict`) that do not
  exist in `lib/commanded/verifiers/`. Treat all `CLAUDE.md` factual claims as unverified.

### Existing, unverified

<!-- Present in the code and not disproved, but never exercised against a real path.
     The rewrite replaces these rather than preserving them. -->

- Spark DSL extensions on `Ash.Resource` (`commands`, `events`, `projections`, `event_handlers`)
  and on `Ash.Domain` (`application`)
- Command and event struct generation with typespecs
- Projection and projector module generation
- Aggregate module generation with execute/apply — 541 generated lines, largest `quote` block 225
  lines against 6–31 for every other generator. This distribution is the reason for the rewrite.
- Command middleware pipeline, parameter transformation and validation, `Ecto.Multi` transaction
  coordination

### Active

**Milestone v0.3 — Library Rewrite (this milestone)**

*Foundation — must land before the first component, because the per-component approval step
depends on it*

- [ ] `mix ash_commanded.dump` — render a DSL definition's generated code: pre-`Module.create/3`
      AST by default, post-compile `:beam_lib` `debug_info` behind a flag
- [ ] Golden renders of generated output, diffed in CI
- [ ] `usage_rules` (dev-only) and generated LLM-facing usage rules for the library
- [ ] AGENTS.md — idiomatic Elixir, DSL conventions, transformer ordering and testing
      expectations, with `core` as the worked reference example
- [ ] `CLAUDE.md` reconciled with reality and made consistent with AGENTS.md rather than divergent
- [ ] Custom Credo checks enforcing the generation anti-patterns (see Constraints → Rewrite rules)
- [ ] Elixir/OTP CI matrix — current release plus the previous two minors (unrun plan 01-08)

*Components — each runs the same loop: propose DSL → usage example → transformer → render and
approve → persisters and verifiers → tests*

- [ ] Commands
- [ ] Events
- [ ] Application — including the router-generation defect that blocks it
- [ ] Aggregates — opening with the design question: what is `AshCommanded.Aggregate.__using__/1`?
- [ ] Projections
- [ ] Routers, event handlers and process managers — requires a domain transformer that walks
      `Ash.Domain.Info.resources/1` and reads each resource's persisted state via
      `Spark.Dsl.Extension.get_persisted/2`; Spark dsl_state is per-module with no built-in
      cross-module aggregation
- [ ] Declarative event versioning through `Commanded.Event.Upcaster`
- [ ] Snapshots re-targeted at `Commanded.Snapshotting`, replacing the adapter behaviour that
      never existed; production-viable storage beyond in-memory ETS
- [ ] Middleware and transaction coordination

*Carry-forwards from Phase 01 that must not be re-discovered*

- [ ] Restore `commanded_application_integration_test.exs.phase2-blocked`, delete its stale
      `Code.ensure_loaded?` guard, and sweep `test/` for the same pattern (`lib/` was swept, `test/` was not)
- [ ] Fix the latent `Ash.run_action(changeset, action)` at `generate_projector_modules.ex:359`
- [ ] Resolve the `private? true` ETS fixture limitation — the table is scoped to the calling
      process, so a write made inside Commanded's aggregate GenServer is invisible to a later
      `Ash.get!/2` from the test process
- [ ] `spark.cheat_sheets` to cover `DomainDsl`, not only `Dsl`
- [ ] `mix.exs` `files:` to include `documentation/` and `cheatsheets/`
- [ ] Replace `IO.puts`/`IO.inspect` in production paths with `Logger`
- [ ] Bump dependencies to current versions (Ash, Spark, ExDoc, Sourceror, Igniter)
- [ ] Revert `workflow.use_worktrees: false` once this branch merges

**Deferred to the next milestone — `core` migration and 1.0**

- [ ] Migrate `identity` onto AshCommanded
- [ ] Migrate `data` onto AshCommanded
- [ ] Migrate `integration` onto AshCommanded
- [ ] Migrate `schema_definition` onto AshCommanded
- [ ] Migrate `workflow` onto AshCommanded
- [ ] Publish 1.0 to hex.pm once `core` is fully migrated

### Out of Scope

- **Backwards compatibility with the published 0.2.0 DSL** — adoption is negligible and the
  aggregate/projection redesign cannot be done additively. Break freely on 0.x; migration notes
  ship with 1.0.
- **Maintaining a private fork** — David is an upstream maintainer, so work lands in
  `accountex-org/ash_commanded` directly.
- **Non-Commanded event-sourcing backends** — the library targets Commanded 1.4.8 specifically.
- **Migrating `core` code that is not event-sourced** — only the CQRS/ES surface is in scope.

## Constraints

- **Tech stack**: Current Elixir/OTP, with the previous two minor Elixir releases supported and CI-tested.
  Presently declared `~> 1.14`; `core` runs `~> 1.18` on OTP 27. The declared floor tightens as part of this work.
- **Dependencies**: Ash ~> 3.0 (3.5.8), Spark ~> 2.3 (2.3.5), Commanded 1.4.8 — upper bounds move to current
  releases, but whatever is chosen must remain installable alongside `core`'s own resolved versions
- **Compatibility**: Must support every pattern `core` uses today, or `core` cannot migrate
- **Licence**: MIT, upstream `accountex-org/ash_commanded` — contributions must suit a public library
- **Genericity**: Examples and tests must be domain-neutral; no Accountex-specific concepts in the published library
- **Versioning**: Break freely on 0.x; 1.0 is cut only after `core` is fully migrated

**Rewrite rules** — foundational, not remedial. Derived from `.planning/LEARNINGS.md` §5 and from
the anti-patterns the previous implementation exhibited. These are gates on the rewrite, and where
possible they are enforced by custom Credo checks rather than by prose.

1. **Generated code is thin wiring.** Logic lives in hand-written runtime modules reached through a
   `__using__` front door. A generated clause carries only the per-entity literals that vary.
2. **Anything computable at macro-expansion time is computed there** and `unquote`d as a literal,
   never reassembled at runtime.
3. **Measure the OUTPUT, not the generator.** Target: a generated clause under ~10 lines; no
   `quote` block over 40. Splitting a fat generator into several generator modules satisfies a
   line-count criterion while changing nothing about what is emitted.
4. **Derive from `Transformer.get_persisted/2`**, never by module-name surgery.
5. **Prefer a verifier over a transformer** when only validating.
6. **Introspection belongs in `ModuleName.Info`.**
7. **Golden renders of generated output, diffed in CI.**
8. **DRY.** Repeated shapes extract to functions, modules or macros rather than recurring.
9. **No double-handling.** Pass the value the caller already holds rather than re-deriving it by
   re-walking nested AST. An extra parameter is cheaper than a traversal.
10. **Idiomatic macros.** Mostly-static code with occasional `unquote` substitutions — never lists
    of tuples and maps assembled into strings and reparsed into AST.
11. **Tricky AST transformation is a smell.** If Spark does not already offer it, the design is
    probably an overcomplicated version of something simple. Escalate and reconsider; a feature PR
    to Spark is the last resort, not the first move. Where genuinely needed, it goes behind a named
    utility module whose purpose is legible.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bar for "production ready" is `core` running on it | A boilerplate-removal library is only credible if it carries a real system; any lesser bar is self-assessed | — Pending |
| `core` migration is inside this project's scope | Changed from "library only" during questioning — direct proof beats indirect proof, and the migration is the payoff | — Pending |
| All five `core` domains, not a pilot | Partial migration leaves `core` maintaining two idioms at once, which is worse than either | — Pending |
| Absorb everything viable into the DSL, not just boilerplate | Boilerplate-only wins file count but leaves 5,345 lines of aggregate/projector logic untouched; escape hatches only where genuinely needed | — Pending |
| Declarative event upcasting is a v1 requirement | `core` depends on `Commanded.Event.Upcaster`; an ES library with no schema-evolution story is incomplete | — Pending |
| Fold the in-flight `fix-application-generation` work into Phase 1 | The Domain/Resource split is correct and already underway; restarting wastes it | ⚠️ Revisit — the split compiles, but router generation never fires under it; the application component of the rewrite now owns this |
| Two example adapters (in-memory + Postgres EventStore) | In-memory keeps docs and CI fast; Postgres proves the path `core` actually uses | — Pending |
| All flagged tech debt in scope | "Production ready" is not compatible with `IO.inspect` in dispatch paths or undeclared dependencies | — Pending |
| Break the DSL now, cut 1.0 later | 0.2.0 adoption is negligible; freezing the DSL before `core` migrates would lock in the gaps this project exists to fix | — Pending |
| Support current Elixir/OTP plus the previous two minors | Standard Hex-library practice: broad enough to adopt, narrow enough to CI-test honestly. `~> 1.14` was untested reach | — Pending |
| Repository tooling (usage_rules, AGENTS.md, dep bumps) is in scope | The library will be worked on largely by coding agents; stale docs and undeclared conventions are the same failure mode as the `CLAUDE.md` drift already found | — Pending |
| Upstream rather than fork | David holds maintainer rights on `accountex-org/ash_commanded` including hex publishing | ✓ Good |
| Rewrite component by component rather than continue refactoring | A generator audit measured `generate_aggregate_module.ex` at 11 `quote` blocks, 225-line largest block and 541 generated lines, against 6–31 for every other generator. The distribution reads as accretion, and the cause is mechanical: Commanded supplies a `__using__` macro for everything except aggregates, so that machinery was written into the emitted AST instead of into a runtime module | — Pending |
| Component order: commands, events, application, then aggregates and projections | Prove the render-and-approve methodology on the cheap components before it meets the hard ones | — Pending |
| The DSL-output renderer is foundation, not a deliverable | Every component's human-approval step depends on it, so it cannot follow the components it gates | — Pending |
| Render both pre-`Module.create/3` AST and post-compile `:beam_lib` | The two views catch different things: pre-create shows what the transformer wrote (with `use X` still `use X`), post-compile shows ground truth after macro expansion | — Pending |
| Rewrite in place, per component, with the suite green at every commit | Phase 01's 176-test suite and blocking gates are the judging bar; a parallel namespace would keep known-broken code alive for the whole milestone and double the surface | — Pending |
| `core` migration deferred to the next milestone | A migration cannot be sensibly phased against a DSL that does not yet exist; the migration roadmap should be written once the new DSL surface is real | — Pending |
| Anti-patterns enforced by executable checks, not prose | "Mostly static code with occasional substitutions" is a countable property of a `quote` block. Prose gates decay once the approving human moves on; Credo checks and golden-render diffs do not | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-15 after starting milestone v0.3 Library Rewrite*
