# Phase 1: Build Integrity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-12
**Phase:** 1-Build Integrity
**Areas discussed:** Commanded/EventStore dependency shape, Test data layer for real Ash, Existing
48-test-file triage, CI gate strictness, Logger migration (QUAL-02), Dependency version targets
(REPO-03), Proving SC2 (test/dev module parity), Fresh-clone bootstrap (SC1), DSL clarity and
authoring rules (user-raised)

---

## Commanded/EventStore Dependency Shape

### Q1 — How should `:commanded` be declared in mix.exs?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `optional: true` (Recommended) | Fetched for the library's own tests, not auto-installed for consumers; honest hex signal | |
| `only: [:dev, :test]` | Present for tests and docs, absent from published package metadata | |
| Hard runtime dependency | Every consumer gets Commanded transitively; simplest mental model | ✓ |

**User's choice:** Hard runtime dependency
**Notes:** Claude's recommendation was not taken. The trade-off accepted is that version conflicts
land on the consumer. Constraint carried into CONTEXT.md: the declared version must stay resolvable
alongside `core`'s Commanded 1.4.8.

### Q2 — And `:eventstore`?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `optional: true` (Recommended) | Visible in hex metadata, not forced; consumers on InMemory avoid inheriting Ecto/Postgrex/migrations | ✓ |
| `only: [:dev, :test]` | Lightest published package, least discoverable | |
| Hard runtime dependency | Symmetric with the `:commanded` choice; forces Postgres provisioning in every CI job | |

**User's choice:** `optional: true`
**Notes:** Deliberately asymmetric with Q1 — the two dependencies were judged to carry different
consumer cost.

### Q3 — The six `Code.ensure_loaded?(Commanded*)` stub-generation fallbacks

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Delete all six branches (Recommended) | Dead by construction once Commanded is a hard dep; removes the silent stub-router failure mode | ✓ |
| Delete, and add a test proving they're gone | Same deletion plus a guard test against stub reintroduction | |
| Keep as a compile-time raise | Replace stubs with a `Spark.Error.DslError` naming the missing package | |

**User's choice:** Delete all six branches
**Notes:** Surfaced during discussion — `generate_main_router_module.ex:216`'s else-branch emits a
router whose `dispatch/1` is `{:ok, command}`, accepting every command and dispatching nothing. This
is a third dishonesty mechanism the requirements do not name (alongside `Mix.env()` and the skip
knobs).

### Q4 — The four `Application.get_env(:ash_commanded, :skip_*_module_creation)` knobs

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Delete the knobs entirely (Recommended) | `create_module/3` called unconditionally; no dial remains | ✓ |
| Keep, default to false | Escape hatch survives for module-name collisions downstream | |
| Delete knobs, keep one global flag | Single `:generate_modules?` setting replacing four | |

**User's choice:** Delete the knobs entirely
**Notes:** Nothing in `config/` or `test/` sets any of the four today — the entire skip behaviour
comes from the `Mix.env() == :test` default.

---

## Test Data Layer for Real Ash

### Q1 — Which Ash data layer backs the test resources?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `Ash.DataLayer.Ets` (Recommended) | Ships in Ash core; no new dep, no Postgres in CI, no migrations | |
| AshPostgres from the start | Real DB from day one, including constraint and transaction semantics | |
| ETS now, AshPostgres added in Phase 5 | ETS carries Phases 1-4; Postgres lands with PROJ-03, which already demands it | ✓ |

**User's choice:** ETS now, AshPostgres added in Phase 5
**Notes:** Distinction drawn during discussion and carried into CONTEXT.md — the Ash data layer
(read-model persistence) and the Commanded event store adapter (event persistence) are independent
axes. Phase 1 needs only the first.

### Q2 — Where do test resources and their domain live?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Hybrid: shared support + inline (Recommended) | `test/support/` for action-execution tests; inline for DSL-rejection tests | ✓ |
| All shared in `test/support/` | One canonical fixture set; least compile time | |
| Keep everything inline per test file | Maximum isolation; repeats domain/data-layer boilerplate | |

**User's choice:** Hybrid: shared support + inline
**Notes:** `mix.exs` has no `elixirc_paths/1` at all today, so `test/support/` is not currently
compiled. The "all shared" option does not fully hold — a resource that fails to compile cannot live
in `test/support/`.

### Q3 — How does a test assert compile-time DSL rejection?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `Code.compile_string` + regex on message (Recommended) | Binds to the distinguishing part; survives Spark error-envelope changes across version bumps | ✓ |
| `Code.compile_string` + exact message string | Strictest; brittle against the Spark `~> 2.6` bump REPO-03 makes | |
| Assert on the verifier directly, unit-style | Fast and precise; does not prove the verifier is wired into the extension | |

**User's choice:** `Code.compile_string` + regex on message
**Notes:** Option 3 was flagged as failing SC3's intent — deleting a verifier from the `verifiers/0`
list would leave those tests passing.

### Q4 — Event-store and aggregate-process isolation (TEST-06 / SC5)

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Unique app name per test, stay async (Recommended) | Own Commanded app + InMemory store per dispatching test; `seed: 0` dropped | ✓ |
| Shared app, `async: false`, reset in setup | Simpler to debug; serialises the slowest tests | |
| Defer isolation design to Phase 2 | Design against observed leakage rather than a guess | |

**User's choice:** Unique app name per test, stay async
**Notes:** `seed: 0` identified during discussion as the mechanism currently hiding order dependence
— it pins ExUnit's shuffle, making order-dependence reproducible rather than visible.

---

## Existing 48-Test-File Triage

### Q1 — How are the existing 48 test files handled?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Delete contrived, rewrite load-bearing (Recommended) | Green baseline first; treat the suite as a liability; fewer tests that mean more | ✓ |
| Fix all 48 in this phase | Nothing deleted; preserves original intent | |
| Tag and quarantine for the owning phase | Phase 1 lands fast; substitutes one masking mechanism for another | |

**User's choice:** Delete contrived, rewrite load-bearing
**Notes:** Survey presented: 48 files / 164 `test` declarations; 13 files assert via
`Code.ensure_loaded?`; 7 use `with_mock`; 4 touch `CommandActionMapper`. Also surfaced — all 9
`:skip_if_no_commanded` tests have never run, because `test_helper.exs:11` excludes them whenever
Commanded is absent, and Commanded is absent. Making it a hard dep un-skips all 9 at once.

### Q2 — The uncommitted `fix-application-generation` work

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Commit as-is first, then Phase 1 on top (Recommended) | Preserves the work, gives a reviewable baseline, keeps Phase 1's diff legible | ✓ |
| Pull the transformer parts into Phase 1 | Avoids editing the same lines twice; splits one coherent change | |
| Commit to a side branch, Phase 1 from clean main | Cleanest Phase 1 diff; rebase would redo work | |

**User's choice:** Commit as-is first, then Phase 1 on top
**Notes:** 88 insertions / 48 deletions across 8 files, three of which
(`generate_aggregate_module.ex`, `generate_event_handler_modules.ex`,
`generate_projector_modules.ex`) carry `Mix.env()` guards Phase 1 must delete. Two DomainDsl commits
(`a956434`, `b259992`) already on the branch.

### Q3 — `test_helper.exs` exclusion machinery

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Delete both, no default exclusions (Recommended) | Reduces to `ExUnit.start()`; a test that cannot pass must be fixed or deleted | ✓ |
| Delete both, add an `:integration` tag excluded by default | Establishes the convention Phase 5's Postgres test will need | |
| Keep `:skip` as an escape hatch | Pragmatic parking; same masking mechanism the phase exists to remove | |

**User's choice:** Delete both, no default exclusions
**Notes:** Consequence noted and deferred — Phase 5's PROJ-03 Postgres integration test now needs an
exclusion convention that has to be introduced deliberately.

### Q4 — Coverage measurement

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Add ExCoveralls, report only, no gate (Recommended) | Honest baseline; number allowed to drop during triage before it climbs | ✓ |
| Add ExCoveralls with an 80% gate | Applies the standing minimum immediately | |
| No coverage tooling in Phase 1 | SC1-SC5 are the gate; no baseline recorded | |

**User's choice:** Add ExCoveralls, report only, no gate
**Notes:** A knowing, scoped departure from the standing 80%-coverage rule, on the grounds that a
gate during triage pressures toward tests that raise coverage rather than tests that catch defects.

---

## CI Gate Strictness

### Q1 — Matrix shape

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Fan out tests, pin slow gates to primary (Recommended) | Tests + warnings-as-errors on all three cells; format/Credo/Dialyzer/docs/coverage once on 1.18+OTP 27 | ✓ |
| Everything on every cell | Maximum signal; three PLTs, triple CI minutes | |
| Single version now, matrix added later | Simplest; REPO-04 asks for the matrix in this phase | |

**User's choice:** Fan out tests, pin slow gates to primary

### Q2 — Credo strictness

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Default strictness, blocking (Recommended) | Catches real problems without failing on module-doc pedantry | ✓ |
| `--strict`, blocking | Matches `core`'s bar; fires on the two oversized modules Phases 4/6 will decompose | |
| Non-blocking in Phase 1, blocking from Phase 2 | Avoids Credo noise during the churn; a gate that does not gate tends to stay that way | |

**User's choice:** Default strictness, blocking
**Notes:** Deliberate divergence from `work/core`, which runs `mix credo -a --strict`. Rationale
recorded in CONTEXT.md D-21.

### Q3 — Dialyzer

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Blocking, with a seeded ignore file (Recommended) | Record existing debt, block anything new; visible list for later phases to shrink | ✓ |
| Blocking with zero ignores | Strongest guarantee; unknown finding count inside a phase that blocks twelve others | |
| Non-blocking, report only | Zero stall risk; findings accumulate unread | |

**User's choice:** Blocking, with a seeded ignore file

### Q4 — Local/CI parity and the docs gate

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `mix check` alias + `gen.docs` as the gate (Recommended) | One-command local reproduction; cheat-sheet generation exercised | ✓ |
| `mix check` alias + plain `mix docs` | Faster; cheat-sheet breakage invisible until Phase 7 | |
| No alias — CI defines the gates | One definition; no one-command local reproduction | |

**User's choice:** `mix check` alias + `gen.docs` as the gate
**Notes:** `spark.cheat_sheets` is currently configured for `AshCommanded.Commanded.Dsl` only, not
`DomainDsl` — deferred to Phase 7's DOCS-04.

---

## Logger Migration (QUAL-02)

### Q1 — `snapshot_store.ex:111`

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `Logger.error` + keep `:error` return (Recommended) | Narrowest change; public contract unchanged | ✓ |
| `Logger.error` + narrow the rescue | Also stops the bare rescue flattening genuine bugs; reaches into Phase 4 | |
| `Logger.error` + return `{:error, reason}` | Most correct long-term; a behaviour change in a phase that cannot yet detect them | |

**User's choice:** `Logger.error` + keep `:error` return
**Notes:** Correction made during discussion — only `snapshot_store.ex:111` is a live `IO.puts`. The
three `base_middleware.ex` hits are inside an `@moduledoc` example block, not executable code.

### Q2 — Guarding QUAL-02 against regression

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Credo check, blocking (Recommended) | `Credo.Check.Warning.IoInspect` + `IExPry`; moduledoc example rewritten to `Logger.debug` | ✓ |
| Credo check + a grep test in the suite | Also covers docstrings, which Credo does not scan; brittle across platforms | |
| Rewrite the example, no automated guard | Nothing new to configure; property decays silently | |

**User's choice:** Credo check, blocking
**Notes:** The `base_middleware.ex` moduledoc example currently teaches `IO.inspect` while
`logging_middleware.ex:102-105` already uses `Logger` properly — the documented example contradicts
the library's own practice.

---

## Dependency Version Targets (REPO-03)

### Q1 — Sourceror and Igniter (zero references anywhere)

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Remove both, add `usage_rules` (Recommended) | Dead deps are compile time and lock surface for nothing | |
| Remove Sourceror, keep Igniter | Bets on a future `mix ash_commanded.install` task | |
| Keep both, just bump versions | REPO-03 says "current", not "pruned" | ✓ |

**User's choice:** Keep both, just bump versions
**Notes:** Claude's recommendation was not taken. Verified during discussion: zero references to
Sourceror or Igniter in `lib/` or `test/`, and no `lib/mix/tasks/` directory exists.

### Q2 — Version-bound style

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Permissive bounds, current lock (Recommended) | `ash ~> 3.0`, `spark ~> 2.6`; lock moves to current so CI tests it | ✓ |
| Tight bounds matching what's tested | Never claims unverified compatibility; forces `core` into lockstep | |
| Permissive for Ash, tight for Spark | Reflects differing risk; two rules to explain | |

**User's choice:** Permissive bounds, current lock

---

## Proving SC2 (Test/Dev Module Parity)

### Q1 — How is SC2 demonstrated?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Dev-visible fixture + cross-env compile check in CI (Recommended) | The only option that literally tests what SC2 states | ✓ |
| Grep guard + behaviour tests, no cross-env compile | Proves the cause is absent rather than the effect equal | |
| Defer the cross-env check to Phase 7 | Example apps are the natural artefact; SC2 is a Phase 1 criterion | |

**User's choice:** Dev-visible fixture + cross-env compile check in CI
**Notes:** Wrinkle surfaced during discussion — generated modules only exist when a *resource*
compiles, and every resource lives under `test/`, so `_build/dev` currently contains no generated
modules at all. The fixture is what makes the comparison possible, and must be domain-neutral.

---

## Fresh-Clone Bootstrap (SC1)

### Q1 — Bootstrap and warnings-as-errors

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| `mix setup` alias + CI installs rebar/hex explicitly (Recommended) | Makes SC1's command true on a genuinely fresh clone | ✓ |
| CI installs rebar only, no setup alias | `erlef/setup-beam` covers CI; SC1 stays false locally | |
| Setup alias, warnings-as-errors as a gate to reach | Sequences unknown debt; the flag could stay off longer than intended | |

**User's choice:** `mix setup` alias + CI installs rebar/hex explicitly
**Notes:** Verified during discussion — `mix test` currently fails on this machine with
`Could not find "rebar3", which is needed to build dependency :telemetry`, so there is no green
baseline to diff against and SC1's literal command is false on a clean machine.

---

## DSL Clarity and Authoring Rules (user-raised mid-discussion)

The user raised a concern not on the original gray-area list: that Spark DSL definitions are
cognitively hard to author well, that the original library's DSL was not comprehensible, and that
in-repo rules plus documentation are needed to prevent a repeat.

Research performed and reported: Spark's
[Writing Extensions guide](https://spark.hexdocs.pm/writing-extensions.html),
[Get Started with Spark](https://hexdocs.pm/spark/get-started-with-spark.html), and
[`Spark.Dsl.Extension`](https://hexdocs.pm/spark/Spark.Dsl.Extension.html). Key structural guidance:
the strict Transformers → Persisters → Verifiers ordering contract; "prefer verifiers over
transformers when you only need to validate"; introspection belongs in a `ModuleName.Info` module.
Also noted that `.planning/research/ARCHITECTURE.md` already documents the
`{:spark_behaviour, _}` / `{:spark_function_behaviour, _, _}` escape-hatch types and the one-way
Domain→Resource boundary.

Assessment given: REPO-01, REPO-02 and DOCS-04 all sit in Phase 7, which schedules the DSL-authoring
rules *after* Phases 2-6 author all the new DSL — rules written last do not shape the work they exist
to govern.

### Q1 — Where do DSL clarity and authoring rules belong?

| Option | Description | Selected |
| -------- | ------------- | ---------- |
| Split: consume rules in Phase 1, author rules move to Phase 2 (Recommended) | Phase 1 syncs Spark's/Ash's own usage rules; a new Phase 2 requirement covers in-repo authoring rules; REPO-01/02 consumer artefacts stay in Phase 7 | ✓ |
| All of it in Phase 1 | Rules before any new DSL is written; Phase 1 already blocks twelve phases | |
| Add a quality constraint, leave the roadmap alone | No roadmap surgery; weakest form — no artefact, no gate | |
| Spike it first | Ground the rules in how Ash itself is written; delays Phase 1 planning | |

**User's choice:** Split — consume rules in Phase 1, author rules move to Phase 2
**Notes:** The Phase 2 half requires a ROADMAP.md and REQUIREMENTS.md edit that has **not** been
applied. Flagged for separate action.

---

## Claude's Discretion

- Whether `{:mock, "~> 0.3.0", only: [:test]}` survives the triage — decide from the outcome, not in
  advance
- Exact Elixir/OTP pairings for the three matrix cells
- Whether CI runs on PRs only or also on push to `main`; dependency cache key
- Whether `test/support` ETS tables are `private?: true` per-process or named
- Whether a `test/support` helper wraps unique-named Commanded app startup, or tests do it inline
- Precise content of `.credo.exs` disables and `.dialyzer_ignore.exs` entries

## Deferred Ideas

- In-repo DSL authoring rules → Phase 2 (**requires a roadmap edit, not yet applied**)
- Consumer-facing `usage-rules.md` and `AGENTS.md` → Phase 7, unchanged (REPO-01, REPO-02)
- An `:integration` tag convention → Phase 5, now that all default exclusions are removed
- `mix.exs` `files:` list omits `documentation/` and `cheatsheets/` → Phase 7
- `spark.cheat_sheets` covers only `AshCommanded.Commanded.Dsl`, not `DomainDsl` → Phase 7 (DOCS-04)
- Bare `rescue` in `snapshot_store.ex` swallowing all exception classes → Phase 4 (SNAP-01..03)
- `Spark.InfoGenerator` adoption and escape-hatch retyping → opportunistic, no dedicated phase
