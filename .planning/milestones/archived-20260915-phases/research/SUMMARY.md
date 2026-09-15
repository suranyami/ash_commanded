# AshCommanded Research Summary

**Project:** AshCommanded — Spark DSL extension for Ash Framework, bringing CQRS and Event Sourcing via Commanded  
**Domain:** Elixir hex library + production event-sourced application migration  
**Researched:** 2026-09-11  
**Confidence:** HIGH (stack/architecture/pitfalls verified against source; features synthesized from Commanded API + `core`'s measured patterns)

---

## Executive Summary

AshCommanded is a Spark DSL extension that generates the boilerplate half of a CQRS/Event Sourcing system built on Commanded 1.4.8 — commands, events, aggregates, projectors, and routers that would otherwise be written by hand, one file at a time. The library has structural pieces in place (command/event/aggregate/projector generation, router wiring, nine verifiers) but is missing three critical capabilities required to migrate `core`'s production event-sourced code: declarative event versioning (no upcasting DSL), aggregate invariants and non-attribute state (the two things `core`'s 1,822 LOC of aggregate code expresses), and projection expressiveness sufficient to absorb 3,523 LOC of "mostly real logic" projector code. The net win from this library is asymmetric but real: 132 of 163 event-sourcing files are pure boilerplate (commands + events, 1,053 LOC total); absorbing those eliminates 80% of files while leaving the 5,345 LOC carrying genuine business logic to be expressed via DSL escape hatches (function callbacks) rather than generated or deleted. No domain can migrate without **both** a custom `TypeProvider` (to decouple new event module paths from historical event-type strings) and the aggregate-invariants DSL capability — these are load-bearing prerequisites, not polish items.

The library's most dangerous pitfall is event-type identity binding: the default Commanded `TypeProvider` couples the serialized event type string to the Elixir module name; a module-path mismatch silently breaks deserialization of 68 historical event types in `core`'s production Postgres store. Three other pitfalls are live (transformer ordering silently drops modules; tests skip module creation by default so test suite doesn't exercise generated code; event store state leaks across tests) and require foundational fixes **before** feature work. The recommended roadmap is: (1) fix these four foundation issues and land the Domain/Resource DSL split already in flight; (2) build event versioning and aggregate-invariants DSL sections; (3) close projection-expressiveness gaps; (4) then migrate domains 1-5 sequentially with golden-trace verification against real historical event data.

---

## Key Findings

### Recommended Stack

Stack research confirms current dependency versions are safe; minimal bumps needed. Key decisions:

- **Elixir `~> 1.18` floor** (current 1.20; project constraint is "previous two minors"). No breaking changes exist between 1.18 and 1.20 affecting this library.
- **OTP 27 primary CI job, 1.18+25 for floor check, 1.20+29 for forward-compat** — OTP 27 is common to all three supported Elixir minors and matches `core`'s runtime exactly.
- **Ash `~> 3.0` (current 3.33.3), Spark `~> 2.6` (not 2.3; Ash itself now requires 2.6+), Commanded `~> 1.4`** — last is critical: currently undeclared despite generated code referencing Commanded macros at compile time. Fix by adding as a hard runtime dependency.
- **Dev tooling bumps:** ex_doc (0.37→0.38+), add credo (1.7), add dialyxir (1.4), keep mock.
- **CI matrix:** 5 jobs (Elixir 1.18.5+OTP25, 1.18.5+OTP27, 1.19.6+OTP27, 1.20.4+OTP27 primary, 1.20.4+OTP29). Format → Credo → compile-with-warnings-as-errors → test → dialyzer → docs.

See STACK.md for full rationale including CI yaml and `usage_rules` setup.

### Expected Features

FEATURES.md maps nine Commanded capabilities against `core`'s real measured needs:

**TABLE STAKES (all gate `core` migration):**

1. **Event upcasting DSL** — `core` already uses `Commanded.Event.Upcaster`. Zero support today. Complexity: **MEDIUM-HIGH**.
2. **Aggregate invariants + multi-event support** — `core`'s 1,822 LOC is "genuine invariants + dispatch plumbing." Complexity: **MEDIUM**.
3. **Non-attribute aggregate state** — `core` aggregates hold `members: %{}` not on resource. Complexity: **MEDIUM-HIGH**.
4. **Production snapshot storage** — Currently ETS-only. Complexity: **LOW** for config; **MEDIUM** for adapter.
5. **Event handler subscription options** (`start_from`, `subscribe_to`, `consistency`) — Complexity: **LOW-MEDIUM**.
6. **Projection read-before-write + `after_update` + function-of-(event,current-record)** — 3,523 LOC projectors. Complexity: **HIGH**.
7. **Full dispatch option passthrough** — Verification task. Complexity: **LOW-MEDIUM**.

**FEATURE DEPENDENCIES (strict ordering):**
- Event versioning convention before/alongside upcaster DSL
- Non-attribute-state with invariants  
- Domain/Resource split before everything else
- Projection transactional safety verified before migration

See FEATURES.md for MVP definition, differentiators, and complete feature landscape.

### Architecture Approach

AshCommanded generates code at compile time via `Module.create/3`. Three critical insights:

**1. Transformer ordering is fragile.** Spark's sort depends on explicit `before?/after?`, not list position. Dead references exist (`ExtractCommands` in `after?` clause but doesn't exist). 6 of 13 transformers declare no ordering. Result: silent missing generation. **Fix required:** total-order list, generate every `after?/1`, make violations errors.

**2. Resource/Domain boundary is one-way read.** Domain reads Resource (Ash forces order); Resource never reads Domain (deadlock risk). `fix-application-generation` implements this correctly and must land first.

**3. Code generation via `quote` + `Module.create/3` is correct.** Commanded dispatches by module name expecting behaviours — modules must be real. Igniter/Sourceror is for scaffolding, not recurring DSL modules.

**Major components:** DSL sections → 13 Transformers → 9 Verifiers → Generated modules. Two oversized files needing decomposition: `GenerateAggregateModule` (861 LOC → 4 builders) and `CommandActionMapper` (640 LOC → 5 executors).

See ARCHITECTURE.md for verified patterns, component boundaries, and build-order implications.

### Critical Pitfalls (Top 5)

1. **Event-type string bound to module name** — Default `TypeProvider` couples serialized event type to module name. Mismatch silently breaks deserialization of 68 historical event types in `core`'s Postgres store. **Fix:** Build explicit `TypeProvider` (MUST precede migration).

2. **Transformer ordering silent failures** — Wrong/missing `before?/after?` runs against empty state, silently produces nothing. **Fix:** Total-order convention, integration test asserting every generated module has declared content.

3. **Compile-time cross-module introspection deadlocks** — Resource transformer calling `Ash.Domain.Info` creates circular dependency. **Fix:** Domain/Resource split + rule: never call Info on non-self.

4. **Verifier gaps** — Three documented verifiers absent. DSL compiles, fails at runtime. **Fix:** Audit against `core`, implement missing, rejection tests with message assertions.

5. **Contrived tests** — Four transformers skip module creation in test by default. Test suite doesn't exercise generated code. **Fix:** Remove skip as default, add real-generation test tier.

See PITFALLS.md for all 13 pitfalls (including upcasting bugs, idempotency, consistency, test isolation, incremental migration, behavior verification) with recovery strategies.

---

## Implications for Roadmap

Research suggests **4 Library Completion phases** then **5 Migration phases** (one per `core` domain). Feature dependencies are load-bearing.

### Library Completion Phase 1: Foundation

**Rationale:** Four blockers prevent everything that follows.

**Delivers:**
- Fix transformer ordering (total-order, generate `after?/1`, integration test)
- Finish Domain/Resource split (`fix-application-generation` lands)
- Build explicit `Commanded.EventStore.TypeProvider` (default mapping)
- Fix test infrastructure (remove skip-module-creation as default)

**Addresses:** Pitfalls 1, 2, 3, 5 (silent failures, event-type mismatches, deadlocks, masked bugs)

---

### Library Completion Phase 2: DSL Capabilities (Table Stakes)

**Rationale:** Three DSL gaps prevent absorbing 1,822 LOC of aggregate logic.

**Delivers:**
- Event versioning DSL (ordered transforms, compile to `defimpl`)
- Aggregate invariants (precondition hook, multi-event via `Multi`)
- Aggregate non-attribute state (independent struct, reducers)

**Addresses:** Table stakes features 1, 2, 3 (gates all migrations)

---

### Library Completion Phase 3: Projection Expressiveness + Quality

**Rationale:** Projections are 3,523 LOC; must get idempotency/consistency right. Quality work enables migrations.

**Delivers:**
- Projection read-before-write, `after_update` hook, function-of-(event,metadata,current-record)
- Idempotency (redelivery tests, `projection_versions` pattern)
- Event handler options in DSL
- Dispatch option passthrough verification
- Decompose oversized modules, missing verifiers, examples, testing story, persistent snapshots

**Addresses:** Table stakes 4, 5, 6, 7; Pitfalls 4, 6, 7, 8, 10  
**Highest-risk:** Projection transactional safety (Ash + `commanded_ecto_projections`). Needs integration test early.

---

### Library Completion Phase 4: Migration Tooling

**Delivers:**
- Golden-trace harness (real Postgres events, replay both old/new, byte-identical check)
- Migration checklist per domain (cross-domain audit, TypeProvider config)
- Module-path mismatch verifier

**Addresses:** Pitfalls 1, 12, 13 (event safety, incremental migration, behavior verification)

---

### Migration Phases 1-5: Sequential Per Domain

**Phases:** `identity` (test Phase 2), then `data`, `integration`, `schema_definition`, `workflow`.

Each domain:
- Migrate commands, events, aggregates, projectors onto DSL
- Golden-trace verification against Postgres history
- Cross-domain consumer audit
- Deploy once behavior verified

**Addresses:** Core value (163 files → ~60 files; 1,053 LOC boilerplate eliminated)

---

### Phase Ordering Rationale

1. **Foundation (Phase 1)** precedes all — test infrastructure and TypeProvider load-bearing.
2. **DSL Capabilities (Phase 2)** before Projection work (Phase 3) — aggregates simpler, gate fewer dependencies.
3. **Projection work (Phase 3)** includes examples/testing — needed before migrations validate.
4. **Migration tooling (Phase 4)** depends on Phase 3 stability.
5. **Migrations (Phases 5+)** sequential due to cross-domain dependencies.

---

### Research Flags

**Phases requiring planning research:**

- **Phase 1:** TypeProvider location (library default or `core`-specific?). Existing `Core.EventTypeTranslator` suggests a pattern.
- **Phase 2:** Aggregate invariant function signature — sample `core`'s actual guards. Confirm `(state, command) -> :ok | {:error, reason}` fits all patterns.
- **Phase 3:** Projection transactional composition (highest-risk dependency). Integration test of Ash + `commanded_ecto_projections`.
- **Phase 4:** Cross-domain event-handler dependencies graph. Determines safe migration sequencing.

**Phases with standard patterns (execute directly):**

- **Phase 1:** Transformer ordering (Spark standard), Domain/Resource split (Ash pattern), test infrastructure (ExUnit standard).
- **Phases 2-3:** Code generation via `quote` + `Module.create/3` (AshOban precedent, identical strategy).
- **Phases 5+:** Execution once Phase 4 tooling exists.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | HIGH | Verified hex.pm 2026-09-11; CI from `ash-project` precedent; Elixir/OTP official. No disputes. |
| **Features** | HIGH | 1:1 mapped to Commanded hexdocs + `core` measured usage (163 files, LOC per category). Verified: no process managers, no multitenancy in `core`. |
| **Architecture** | HIGH | Spark ordering traced through source. Domain/Resource boundary verified vs Ash semantics. Code-generation strategy validated vs AshOban. 3 transformer bugs documented. |
| **Pitfalls** | MEDIUM-HIGH | 1-5 verified in source or omissions. 6-10 inferred from Commanded docs + event-sourcing patterns (MEDIUM). 12-13 inferred from append-only constraints (MEDIUM). Orchestrator verified 4 live bugs. |

**Overall: HIGH** — roadmap grounded in verified architecture, measured patterns, live bugs. Dependencies tightly constrained by Commanded semantics.

### Gaps to Address During Planning

1. **TypeProvider location** — Library default or domain-specific. Affects Phase 1 design.
2. **Invariant function signature validation** — Sample `core` guards against proposed signature. If signature doesn't fit, Phase 2 DSL design adjusts.
3. **Cross-domain dependencies graph** — Determines safe migration sequencing. May force domains to migrate together.
4. **Snapshot adapter persistence** — Postgres? S3? Pluggable interface? Phase 3 requires decision.
5. **Projection idempotency strategy** — Use `commanded_ecto_projections` macro or hand-roll? Affects generated AST.

---

## Sources

### Primary — Verified Against Upstream (HIGH confidence)

- **Commanded 1.4.x API** — hexdocs + GitHub; upcasting, projections, aggregate API, dispatch, consistency
- **Spark 2.3.5–2.4.1** — hexdocs + local `deps/spark`; transformer ordering, verifier semantics
- **Ash 3.33.3** — hexdocs + `deps/ash`; resource/domain compilation, Info semantics
- **Hex.pm package API** — Live 2026-09-11; versions and CHANGELOG breaking changes

### Secondary — Measured Against Codebase (HIGH confidence)

- **`core` event-sourced surface** — Measured 2026-09-11; 163 files / 6,398 LOC; patterns via grep
- **AshCommanded live bugs** — Verified in source; transformer skips, dead references, absent verifiers, hardcoded mocks

### Tertiary — Best-Practice Patterns (MEDIUM confidence)

- **Golden-trace tests** — Event-sourcing literature + `ash-project/ash` precedent
- **Migration pitfalls** — Inferred from append-only-log design constraints

---

*Research completed: 2026-09-11*  
*Ready for roadmap: yes, with Phase 1 scope decision needed*
