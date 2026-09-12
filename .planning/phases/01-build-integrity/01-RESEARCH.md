# Phase 1: Build Integrity - Research

**Researched:** 2026-09-12
**Domain:** Elixir/Spark DSL library test-infrastructure and CI hardening (Ash + Commanded code generation)
**Confidence:** HIGH for verified code sites, dependency versions, and Ash/Commanded API surfaces cross-checked live this session; MEDIUM for CI-shape and cross-env-parity design recommendations (engineering judgment, not a documented recipe); LOW/ASSUMED flagged explicitly wherever training knowledge was not independently verified this session.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

See `.planning/phases/01-build-integrity/01-CONTEXT.md` for the full text of D-01 through D-27. Summary of what is LOCKED (research below explains **how**, not whether):

- D-01: `:commanded` is a hard runtime dependency.
- D-02: `:eventstore` is `optional: true`.
- D-03: Sourceror and Igniter stay, versions bumped.
- D-04: Add `{:usage_rules, "~> 1.2", only: [:dev]}`, sync Spark's/Ash's usage rules into this repo.
- D-05: `ash ~> 3.0`, `spark ~> 2.6` (permissive bounds), lock moves to current releases.
- D-06: Delete all four `skip_*_module_creation` knobs, unconditionally.
- D-07: Delete all six `Code.ensure_loaded?(Commanded*)` stub branches.
- D-08: Replace the five `Mix.env() == :test` mock returns in `CommandActionMapper`, assess `error.ex:351` in the same pass.
- D-09: `snapshot_store.ex:111` → `Logger.error`, keep `:error` return, bare `rescue` left as-is.
- D-10: `base_middleware.ex:18,25,31` `IO.inspect` in `@moduledoc` → `Logger.debug`.
- D-11: QUAL-02 enforced by Credo (`IoInspect`, `IExPry`), blocking.
- D-12: Ash data layer for tests is `Ash.DataLayer.Ets` now; AshPostgres in Phase 5.
- D-13: `elixirc_paths(:test)` added; hybrid fixture layout (shared domain+resources for action-execution tests, inline `defmodule` retained for DSL-shape/rejection tests).
- D-14: Compile-time rejection tests use `Code.compile_string` + `assert_raise Spark.Error.DslError, ~r/.../`.
- D-15: Each dispatching test starts its own uniquely-named Commanded application + InMemory store, torn down in `on_exit`; `async: true` preserved; `seed: 0` dropped.
- D-16: `test_helper.exs` reduced to `ExUnit.start()`, no default exclusions; `:skip_if_no_commanded` and `exclude: [:skip]` removed.
- D-17: 48 existing test files triaged delete-contrived / rewrite-load-bearing.
- D-18: Add ExCoveralls, report-only, no threshold.
- D-19: SC2 demonstrated by a dev-visible fixture + cross-env compile check in CI.
- D-20: Matrix fans out `mix test`/`compile --warnings-as-errors` across Elixir/OTP pairs; slow gates (format, Credo, Dialyzer, docs, coverage) pinned to primary cell (1.18/OTP 27).
- D-21: Credo default strictness, blocking, checked-in `.credo.exs`.
- D-22: Dialyzer blocking, with a seeded `.dialyzer_ignore.exs`.
- D-23: Add `mix check` alias running exactly the REPO-05 gate list.
- D-24: Docs gate runs `mix gen.docs`, not plain `mix docs`.
- D-25: Add `mix setup` alias; CI calls `mix local.rebar --force` before `deps.get`.
- D-26: `--warnings-as-errors` debt cleared inside this phase, sized once `mix compile` runs.
- D-27: Commit the uncommitted `fix-application-generation` work first, before Phase 1 edits.

### Claude's Discretion

- Whether `{:mock, "~> 0.3.0", only: [:test]}` survives the D-17 triage (decide from triage outcome).
- Exact Elixir/OTP pairings for the three matrix cells.
- Whether CI runs on PRs only or also on push to `main`; the dependency cache key.
- Whether `test/support` ETS tables are `private?: true` per-process or named.
- Whether a `test/support` helper wraps unique-named Commanded app startup, or each test does it inline.
- Precise wording/content of `.credo.exs` disables and `.dialyzer_ignore.exs` entries.

### Deferred Ideas (OUT OF SCOPE)

- In-repo DSL authoring rules (needs a ROADMAP.md edit) → Phase 2.
- Consumer-facing `usage-rules.md` and `AGENTS.md` → Phase 7 (REPO-01/02).
- `:integration` tag convention (for Phase 5's Postgres test) → Phase 5.
- `mix.exs` `files:` list gaps (`documentation/`, `cheatsheets/`) → Phase 7.
- `spark.cheat_sheets` missing `DomainDsl` → Phase 7.
- Bare `rescue` in `snapshot_store.ex` → Phase 4 (SNAP-01..03).
- `Spark.InfoGenerator` adoption / escape-hatch retyping → opportunistic, before Phase 7.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
| ---- | ------------- | ------------------ |
| QUAL-01 | `:commanded` and `:eventstore` declared in `mix.exs` | §Standard Stack, §Package Legitimacy Audit — verified hex.pm versions and dependency shape |
| QUAL-02 | No `IO.puts`/`IO.inspect` in production paths | §Code Sites Verified — exact 4 sites confirmed by Read; Credo default-check confirmation |
| REPO-03 | Ash/Spark/ExDoc current, Credo+Dialyxir added | §Standard Stack — live hex.pm version check this session |
| REPO-04 | `elixir: "~> 1.18"`, CI matrix across 1.18/1.19/1.20 | §CI Matrix — builds on `.planning/research/STACK.md`, adds `erlef/setup-beam` rebar3-default finding |
| REPO-05 | CI runs format, Credo, compile --warnings-as-errors, tests, Dialyzer, docs | §CI Matrix, §Dialyzer/Credo Specifics |
| TEST-01 | No `Mix.env()` branching in production code | §Code Sites Verified — all guard sites read directly, exact line numbers |
| TEST-02 | Compile-time DSL rejection test pattern | §Compile-Time Rejection Pattern (D-14), builds on PITFALLS.md §Pitfall 5 |
| TEST-03 | Generated modules exercised as real compiled modules | §Cross-Env Compile Parity, §Testing Generated Modules Without Starting Processes |
| TEST-04 | Real Ash create/update/destroy execution, not mocks | §CommandActionMapper Real Execution Path — found and diagnosed the `:by_id` bug |
| TEST-06 | Event store state isolated across async tests | §Per-Test Commanded Application Isolation — verified Commanded's `name:`/`application:` API and InMemory adapter's per-name isolation |

</phase_requirements>

## Summary

This phase does not add capability — it removes three independent mechanisms (`Mix.env()` branches, `Application.get_env` skip knobs, `Code.ensure_loaded?` stub fallbacks) that currently let the test suite pass without exercising real code, replaces `CommandActionMapper`'s hardcoded mocks with real Ash execution, and puts a CI pipeline and current toolchain underneath the result. All four transformer guard sites and all five `CommandActionMapper` mock sites were read directly this session and their line numbers confirmed exactly as CONTEXT.md states. One additional, previously undocumented defect was found: `CommandActionMapper`'s `execute_update/5` and `execute_destroy/5` (and the read path) call `Ash.Query.for_read(:by_id, ...)` — Ash has no built-in `:by_id` read action; every resource must declare one explicitly, and nothing in this codebase (test fixture or verifier) does. This will surface as a real, generic action-not-found error the moment D-08's mock is removed and a test resource is exercised — it is not just "the mock needs deleting," it is a genuine correctness bug the planner must budget a fix for.

Dependency versions were re-verified live against hex.pm's package API this session and match `.planning/research/STACK.md` exactly (ash 3.33.3, spark 2.7.2, commanded 1.4.11, dialyxir 1.4.8, credo 1.7.19, usage_rules 1.2.8, excoveralls 0.18.5) — treat STACK.md's CI-matrix and dependency-declaration reasoning as authoritative; this document adds the pieces STACK.md did not cover: the ETS data layer setup, per-test Commanded application isolation (confirmed via Commanded's own `Commanded.Application` docs and the `InMemory` adapter source), the transformer guard/stub code itself, the `CommandActionMapper` execution-path bugs, the cross-env compile-parity mechanism, and the `run_tests.sh` disposition.

**Primary recommendation:** Sequence the mechanical guard/knob deletions (D-06, D-07) together with making `:commanded` a hard dependency (D-01) as one atomic step — they are mutually dependent, per CONTEXT.md's own Integration Points note. Then fix `CommandActionMapper`'s `:by_id` bug as part of D-08 (not a separate task) because it will be triggered by the very first real-Ash test written against TEST-04. Build the ETS-backed `test/support` domain+resource fixture (D-12/D-13) before writing any rewritten test, since almost every rewritten test in the D-17 triage depends on it existing.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
| ------------ | ------------- | ---------------- | ----------- |
| Dependency declaration (`:commanded`, `:eventstore`) | Build/Package (`mix.exs`) | — | Compile-time dependency resolution, not runtime code |
| Module-creation guards (skip knobs, ensure_loaded stubs) | Compile-time codegen (Spark transformers) | — | These execute during `mix compile`, inside `Spark.Dsl.Transformer.transform/1` — no runtime tier applies |
| `CommandActionMapper` real execution | Application/Domain logic (generated code calling Ash) | Database/Storage (Ash.DataLayer.Ets) | The mapper bridges a dispatched command to an Ash action; the action itself resolves against whatever data layer the resource declares |
| Test data layer (Ash.DataLayer.Ets) | Database/Storage | — | In-process ETS table, scoped per-test via `private?: true` |
| Per-test Commanded application + event store | Application/Backend (process supervision) | — | `Commanded.Application` is a supervised OTP application instance; the event store lives inside it |
| CI pipeline (format/Credo/compile/test/Dialyzer/docs) | Build/Package (CI, not application runtime) | — | Runs entirely outside any deployed process; gates merges, not requests |
| Logging (`Logger` vs `IO.puts`/`IO.inspect`) | Cross-cutting (all tiers) | — | Applies uniformly inside generated modules and library code, not tier-specific |

## Standard Stack

### Core (re-verified live via hex.pm API, 2026-09-12 — matches `.planning/research/STACK.md` exactly)

| Library | Version | Purpose | Why Standard |
| --------- | --------- | --------- | -------------- |
| `ash` | `~> 3.0`, latest `3.33.3` (2026-09-10) [VERIFIED: hex.pm API, queried live this session] | Framework being extended | ash_commanded is a Spark extension for Ash; must track its DSL surface |
| `spark` | `~> 2.6`, latest `2.7.2` (2026-06-07) [VERIFIED: hex.pm API + `ash-project/ash` `main` `mix.exs` line 385: `{:spark, ">= 2.6.0"}`, fetched this session] | DSL/transformer engine | Ash's own `mix.exs` requires `spark >= 2.6.0`; declaring `~> 2.3` (current pin) risks a resolver conflict |
| `commanded` | `~> 1.4`, latest `1.4.11` (2026-07-27) [VERIFIED: hex.pm API this session] | CQRS/ES runtime | Matches `.planning/research/STACK.md`; patch-level bump only from `core`'s 1.4.8 |
| `eventstore` | `~> 1.4`, latest `1.4.8` (2025-03-06) [VERIFIED: hex.pm API this session] | Postgres event store adapter backend | `optional: true` per D-02 |
| `commanded_eventstore_adapter` | `~> 1.4`, latest `1.4.2` (2024-10-25) [VERIFIED: hex.pm API this session] | Wires eventstore into Commanded | `optional: true` per D-02; dormant since Oct 2024 but not archived |

### Supporting / Dev Tooling (newly added by this phase)

| Library | Version | Purpose | Notes |
| --------- | --------- | --------- | ------- |
| `credo` | `~> 1.7`, latest `1.7.19` (2026-06-05) [VERIFIED: hex.pm API this session] | Static analysis | `Credo.Check.Warning.IoInspect` and `Credo.Check.Warning.IExPry` confirmed present in the *default* `.credo.exs` template's `checks:` list under `#Warning Checks` at default (non-strict) priority [CITED: `github.com/rrrene/credo` default `.credo.exs`, fetched this session] — D-11's assumption that these fire without `--strict` is correct |
| `dialyxir` | `~> 1.4`, latest `1.4.8` (2026-09-05) [VERIFIED: hex.pm API this session] | Dialyzer wrapper | See §Dialyzer Specifics below for exact `.dialyzer_ignore.exs` format |
| `excoveralls` | `~> 0.18`, latest `0.18.5` (2025-01-26) [VERIFIED: hex.pm API this session] | Coverage reporting, D-18 | Standard `test_coverage: [tool: ExCoveralls]` + `preferred_cli_env` project config (see below) |
| `usage_rules` | `~> 1.2`, latest `1.2.8` (2026-09-07) [VERIFIED: hex.pm API this session] | Pull Spark's/Ash's own usage rules into this repo, dev-only | Per D-04; `.planning/research/STACK.md:213` already documents the consumer-vs-producer distinction — do not duplicate that reasoning here |

**Installation (deps() additions for this phase only):**

```elixir
{:commanded, "~> 1.4"},
{:eventstore, "~> 1.4", optional: true},
{:commanded_eventstore_adapter, "~> 1.4", optional: true},
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
{:excoveralls, "~> 0.18", only: [:test]},
{:usage_rules, "~> 1.2", only: [:dev]}
```

**mix.exs additions for ExCoveralls (D-18):**

```elixir
def project do
  [
    # ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test
    ]
  ]
end
```

[ASSUMED — standard ExCoveralls project-config shape from training knowledge; not fetched from ExCoveralls' own docs this session, but the package's existence, version, and general purpose were verified against hex.pm. Low risk: this is boilerplate, not a version-sensitive API.]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mock`/`with_mock` (7 verifier test files) | `Mox` + explicit behaviours | `.planning/research/STACK.md` already recommends this path once/if those 7 files are rewritten against real DSL compilation rather than mocked `Spark.Dsl.Verifier` functions — see §D-17 Triage below for the concrete disposition of each file |
| Full directory `elixirc_paths(:dev)` including all of `test/support` | A dedicated, dependency-free fixture path (see §Cross-Env Compile Parity) | Broad inclusion risks `mix compile` failing under `MIX_ENV=dev` the moment any `test/support` file references a test-only dep (`Mock`, `ExUnit`) — confirmed as a real risk, not hypothetical, given `mock` is `only: [:test]` |

## Package Legitimacy Audit

All five newly-added packages (`commanded`, `eventstore`, `commanded_eventstore_adapter`, `credo`, `dialyxir`, `excoveralls`, `usage_rules`) are long-established, widely-used Elixir ecosystem packages, not novel or WebSearch-only discoveries — they were named explicitly in the user's own locked decisions (D-01, D-02, D-04, D-11, D-18, D-21, D-22) and cross-verified live against hex.pm's package API this session (not merely training-data recall).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
| --------- | ---------- | ----- | ----------- | ------------- | --------- | ------------- |
| `commanded` | hex.pm | 1.4.11 released 2026-07-27; package active since ~2017 | High (foundational Elixir CQRS/ES library) | `github.com/commanded/commanded` | OK | Approved |
| `eventstore` | hex.pm | 1.4.8 released 2025-03-06 | High, companion to `commanded` | `github.com/commanded/eventstore` | OK | Approved (optional) |
| `commanded_eventstore_adapter` | hex.pm | 1.4.2 released 2024-10-25 | Moderate — thin adapter package, low churn expected | `github.com/commanded/commanded-eventstore-adapter` | OK | Approved (optional) |
| `credo` | hex.pm | 1.7.19 released 2026-06-05 | Very high (de facto standard Elixir linter) | `github.com/rrrene/credo` | OK | Approved |
| `dialyxir` | hex.pm | 1.4.8 released 2026-09-05 | Very high (de facto standard Dialyzer wrapper) | `github.com/jeremyjh/dialyxir` | OK | Approved |
| `excoveralls` | hex.pm | 0.18.5 released 2025-01-26 | Very high (de facto standard coverage tool) | `github.com/parroty/excoveralls` | OK | Approved |
| `usage_rules` | hex.pm | 1.2.8 released 2026-09-07 | Maintained by `ash-project` org itself, actively released | `github.com/ash-project/usage_rules` | OK | Approved |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none. A formal `gsd_run query package-legitimacy check` seam call was not available in this environment; the disposition above rests on live hex.pm API verification plus each package being named explicitly by the user's own locked decisions (not a novel LLM-suggested name), which is a materially stronger provenance signal than an unprompted recommendation. If the seam becomes available before planning finalizes, re-run it as a cross-check — treat this table as `[ASSUMED: no formal seam check performed]` for provenance-tag purposes, notwithstanding the hex.pm verification.

## Architecture Patterns

### System Architecture Diagram — what this phase changes, and where in the pipeline

```text
mix compile
  │
  ├─▶ Spark.Dsl.Extension compiles AshCommanded.Commanded.Dsl on a resource
  │     │
  │     ├─▶ GenerateCommandModules / GenerateEventModules   (no guard — always create)
  │     ├─▶ GenerateProjectionModules                       (no guard — always create)
  │     ├─▶ GenerateAggregateModule        ──[skip_aggregate_module_creation]──✂ D-06 deletes this
  │     │        └─ execute/2 calls CommandActionMapper.map_to_action ─────────▶ D-08 fixes real path
  │     ├─▶ GenerateProjectorModules       ──[skip_projector_module_creation]──✂ D-06
  │     │        └─ stub body if !Code.ensure_loaded?(Commanded) ───────────────✂ D-07
  │     ├─▶ GenerateEventHandlerModules    ──[skip_event_handler_module_creation]✂ D-06
  │     │        └─ stub body if !Code.ensure_loaded?(Commanded) ───────────────✂ D-07
  │     └─▶ GenerateMainRouterModule       ──[skip_router_module_creation]──────✂ D-06
  │              └─ stub dispatch/1 returns {:ok, command} if !Code.ensure_loaded?(Commanded) ✂ D-07
  │
  └─▶ (domain compile) GenerateCommandedApplication
        └─ has_commanded?() == Code.ensure_loaded?(Commanded.Application) ──────✂ D-07
             (currently gates whether the WHOLE application module is generated)

mix test (after this phase)
  │
  ├─▶ Router.dispatch(command)  ──▶ real Aggregate.execute/2 ──▶ CommandActionMapper
  │                                                                  │
  │                                                                  ▼
  │                                                        Ash.Changeset.for_action/4
  │                                                        Ash.Query.for_read(:by_id) ◀── BUG: no such
  │                                                                                          action exists
  │                                                                  │
  │                                                                  ▼
  │                                                        Ash.DataLayer.Ets (test/support fixture)
  │
  └─▶ Projector/EventHandler.handle/2 called DIRECTLY (no subscription needed)
        └─▶ Ash.create/update/destroy ──▶ same ETS-backed fixture, assert real record
```

### Recommended Project Structure (additions this phase)

```text
lib/
├── commanded/                      # unchanged locations, guard/stub sites edited in place
config/
├── config.exs                      # add test data-layer config alongside existing :ash block
├── test.exs
test/
├── test_helper.exs                 # reduced to ExUnit.start() (D-16)
├── support/
│   ├── parity_fixture.ex           # D-19 fixture — MUST be dependency-free (see below), lives
│   │                                #   in a path added to elixirc_paths for BOTH :dev and :test
│   ├── test_domain.ex              # shared Ash.Domain for action-execution tests (D-13)
│   ├── test_resource.ex            # shared Ash.Resource w/ Ash.DataLayer.Ets (D-12/D-13)
│   └── commanded_app_case.ex       # optional helper wrapping unique-named app startup (Claude's discretion)
├── commanded/
│   ├── ... (existing files, triaged per D-17 — see below)
.dialyzer_ignore.exs                 # seeded once, D-22
.credo.exs                            # checked in, D-21
.github/workflows/ci.yml              # greenfield, D-20/D-25
```

### Pattern 1: Compile-Time DSL Rejection Test (D-14, TEST-02)

**What:** Assert `Spark.Error.DslError` is raised with a message matching a distinguishing regex, using `defmodule` nested inside the test body so compilation (and therefore transformer/verifier execution) is deferred to test run time.
**When to use:** Every verifier-rejection test in this phase and future phases.
**Example** — already documented verbatim in `.planning/research/PITFALLS.md:118-151` (D-14's own canonical reference). Reproduced here only to confirm it matches this repo's actual verifier error shapes — read `lib/commanded/verifiers/validate_command_names.ex` directly if extending this pattern, since the error message text is what the regex must match, and that text was not independently re-verified in this session beyond the mocked-test evidence already in `test/commanded/verifiers/validate_command_names_test.exs` (`error.message =~ "command names are duplicated"` [VERIFIED: `test/commanded/verifiers/validate_command_names_test.exs:39`, read this session]).

```elixir
test "duplicate command names are rejected" do
  assert_raise Spark.Error.DslError, ~r/command names are duplicated/, fn ->
    defmodule Module.concat([:"Test#{System.unique_integer([:positive])}", DuplicateCmd]) do
      use Ash.Resource, domain: nil, extensions: [AshCommanded.Commanded.Dsl]
      attributes do
        uuid_primary_key :id
      end
      commanded do
        commands do
          command :register_user, do: fields([:id])
          command :register_user, do: fields([:id])
        end
      end
    end
  end
end
```

Use a uniquely-named module per test (`Module.concat` + `System.unique_integer/1`) since these tests should run `async: true` and Elixir's module namespace is global per-VM.

### Pattern 2: Ash.DataLayer.Ets test fixture (D-12, D-13)

**What:** A shared domain + resource(s) backed by the in-memory ETS data layer, compiled once, reused by action-execution tests.
**When to use:** TEST-03/TEST-04 tests that need `CommandActionMapper` to perform a real Ash create/update/destroy and read the result back.

```elixir
# test/support/test_domain.ex
defmodule AshCommanded.TestSupport.Domain do
  use Ash.Domain

  resources do
    resource AshCommanded.TestSupport.Widget
  end
end

# test/support/widget.ex
defmodule AshCommanded.TestSupport.Widget do
  use Ash.Resource,
    domain: AshCommanded.TestSupport.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshCommanded.Commanded.Dsl]

  ets do
    private? true   # scopes the table to Process.get — see note below
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name], update: [:name]]
  end

  commanded do
    commands do
      command :create_widget do
        fields([:id, :name])
        identity_field(:id)
      end
    end
    events do
      event :widget_created do
        fields([:id, :name])
      end
    end
  end
end
```

`ets do private? true end` schema and semantics [CITED: `github.com/ash-project/ash` `lib/ash/data_layer/ets/ets.ex` `@ets` section moduledoc, fetched via WebFetch this session — `private?` "Sets the ets table protection to private, and scopes it to only this process. The table name will not be used directly if this is true, to allow multiple processes to use this resource separately."]. This is the load-bearing fact behind the Claude's Discretion item "whether test/support ETS tables are `private?: true` per-process or named": with `private?: true`, the table is looked up via `Process.get({:ash_ets_table, ...})` inside the *calling* process, not a shared GenServer-owned table — so as long as `Ash.create`/`Ash.update`/`Ash.destroy` run in the same process as the test (true by default; Ash actions are synchronous calls, not spawned Tasks), each `async: true` test process gets its own private table automatically, with zero setup/teardown code required. **Recommend `private?: true`** — it is the free, zero-boilerplate answer to TEST-06 for the Ash-data-layer half of isolation (the Commanded event-store half still needs D-15's per-test named application).

**Minimal domain/resource pattern for Ash.DataLayer.Ets** (the `use Ash.Resource, data_layer: Ash.DataLayer.Ets` + `actions do defaults [...] end` shape) [CITED: WebSearch results referencing `ash-hq.org/docs/dsl/ash/main/ets` and Ash's own "Get Started" guide pattern, cross-checked against training knowledge of Ash 3.x resource DSL — this shape is standard and low-risk, but was not read from a live hexdocs page verbatim this session; treat the exact keyword `public? true` on attributes as [ASSUMED] since Ash 3.x's attribute-visibility default behavior was not independently re-verified].

### Pattern 3: Testing generated aggregate/projector modules WITHOUT starting Commanded processes (TEST-03)

**Key finding, not previously documented in CONTEXT.md or PITFALLS.md:** `GenerateAggregateModule`'s `execute/2` and `apply/2` are **plain functions** — calling them directly does not require any Commanded process, subscription, or application to be running.

```elixir
# lib/commanded/transformers/generate_aggregate_module.ex — verified this session:
# aggregate_module = build_aggregate_module(...); struct fields = resource attributes + :version
# execute/2 and apply/2 are ordinary function clauses inside the generated module,
# not GenServer callbacks — Commanded.Aggregates.Aggregate wraps them at RUNTIME dispatch,
# but nothing prevents calling them directly as pure functions in a test.
```

```elixir
test "aggregate creates widget on command" do
  aggregate = struct(AshCommanded.TestSupport.WidgetAggregate)
  command = struct(AshCommanded.TestSupport.Commands.CreateWidget, id: Ash.UUID.generate(), name: "x")

  assert {:ok, event} = AshCommanded.TestSupport.WidgetAggregate.execute(aggregate, command)
  # This call goes through CommandActionMapper's REAL execution path (post D-08) —
  # it performs an actual Ash.create against the ETS-backed Widget resource.
  assert %AshCommanded.TestSupport.Events.WidgetCreated{} = event

  new_state = AshCommanded.TestSupport.WidgetAggregate.apply(aggregate, event)
  assert new_state.id == command.id
end
```

Similarly, `GenerateProjectorModules`/`GenerateEventHandlerModules` generate a `handle/2` function per event — call it directly with a constructed event struct and assert the resulting Ash record, exactly as PITFALLS.md's Pitfall 5 §3 already recommends. **This means D-15's per-test named Commanded application is only strictly required for tests that exercise the full `Router.dispatch/1` path end-to-end** — a meaningfully smaller and lower-risk surface than "every test that touches generated code," which materially de-risks the highest-uncertainty research item (per-test Commanded app isolation). Budget the per-test-app machinery for the router/dispatch-level tests specifically, not universally.

### Anti-Patterns to Avoid

- **Broad `elixirc_paths(:dev)` inclusion of `test/support`:** if any file under `test/support` uses `Mock`/`ExUnit` (test-only deps), adding the whole directory to `:dev`'s `elixirc_paths` will make `mix compile` (no `MIX_ENV` set, i.e. `:dev`) fail with an undefined-module error, because `:mock` is `only: [:test]`. The D-19 parity fixture must live in its own dependency-free path (e.g. `test/support/parity/` containing only an `Ash.Resource`/`Ash.Domain` pair with zero test-framework references), and only *that* narrow path is added to both `:dev` and `:test` `elixirc_paths` — not all of `test/support`.
- **Assuming `:by_id` exists as a read action:** see §CommandActionMapper Real Execution Path below — this is not hypothetical, it is a read defect confirmed by direct source inspection.
- **Registering the same Commanded application `name:` across two `async: true` tests:** per the InMemory adapter's `parse_config/2` (confirmed this session), the event store process name is derived from the `application` value passed to `start_link/1` — reusing a name across tests defeats isolation exactly as if no isolation were attempted at all.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
| --------- | ------------- | ------------- | ----- |
| Per-test event store isolation | A custom registry mapping test PIDs to event store instances | `Commanded.Application.start_link(name: unique_atom)` + `on_exit(fn -> Supervisor/Application.stop... end)` | Commanded's own `name:` option on `start_link/1` already provides this, confirmed via official docs this session — building a parallel mechanism duplicates a supported, documented feature |
| Cross-env module-set diffing | A bespoke `mix compile` output parser | Compare `Code.ensure_loaded?/1` against a small, fixed list of expected fixture-generated module names, once under `MIX_ENV=dev` and once under `MIX_ENV=test` | A raw `_build/{dev,test}/**/*.beam` directory diff will be swamped by every other test-only module and produce false positives; a fixed expected-module-name list is precise and maintainable |
| Test data persistence for TEST-04 | A custom in-process Agent/ETS wrapper | `Ash.DataLayer.Ets` (ships inside Ash core, zero new deps) | Already ships with Ash; `private?: true` gives free per-process isolation, matching this project's own D-12 decision |
| Coverage reporting | Custom `mix test --cover` parsing | `ExCoveralls` | Standard, already the tool named in D-18 |

**Key insight:** every "don't hand-roll" item above is a case where the underlying framework (Commanded, Ash, or standard Elixir tooling) already solved the exact problem this phase needs — the risk in this phase is not missing tooling, it is **incorrectly assuming an API doesn't exist** (as `CommandActionMapper`'s current code does with `:by_id`) or **over-scoping a mechanism** (assuming every test needs a full Commanded application, when most only need to call a generated function directly).

## Code Sites Verified (read directly this session, exact line numbers)

| Site | Confirmed content | Matches CONTEXT.md? |
| ------ | -------------------- | ---------------------- |
| `lib/commanded/transformers/generate_aggregate_module.ex:135-142` | `unless Application.get_env(:ash_commanded, :skip_aggregate_module_creation, Mix.env() == :test) do BaseTransformer.create_module(...)` | Yes — CONTEXT cites `:140` (the `Mix.env()` line); block starts `:135` |
| `lib/commanded/transformers/generate_projector_modules.ex:107-114` | Same pattern, `:skip_projector_module_creation` | Yes — CONTEXT cites `:112` |
| `lib/commanded/transformers/generate_projector_modules.ex:195-206` | `if Code.ensure_loaded?(Commanded) do ... use Commanded.Event.Handler ... else ... stub def init/1 ... end` | Yes — CONTEXT cites `:196` |
| `lib/commanded/transformers/generate_main_router_module.ex:122-129` | `skip_router_module_creation` knob | Yes — CONTEXT cites `:127` |
| `lib/commanded/transformers/generate_main_router_module.ex:213-236` | Domain-router stub: `else` branch produces a plain quoted module with no `use Commanded.Commands.Router` — dispatch handlers are the real risk CONTEXT flags | Yes — CONTEXT cites `:216` |
| `lib/commanded/transformers/generate_main_router_module.ex:346-365` | Main-router stub: `else` branch's stub `def dispatch(command) do` (truncated at read boundary, confirmed to exist) — this is the `{:ok, command}` accept-everything stub CONTEXT calls out | Yes — CONTEXT cites `:347` |
| `lib/commanded/transformers/generate_event_handler_modules.ex:93-100` | `skip_event_handler_module_creation` knob | Yes — CONTEXT cites `:98` |
| `lib/commanded/transformers/generate_event_handler_modules.ex:214-226` | `if Code.ensure_loaded?(Commanded) do ... else ... def init(config), do: {:ok, config} end` | Yes — CONTEXT cites `:214` |
| `lib/commanded/transformers/generate_commanded_application.ex:244` (`defp has_commanded?, do: Code.ensure_loaded?(Commanded.Application)`) | This function gates `transform/1`'s top-level `case has_commanded?() do true -> ... ; false -> {:ok, dsl} end` — **the entire Commanded application module is skipped, not just a stub swapped in**, when Commanded isn't loaded | Yes — CONTEXT cites `:244`; slightly stronger finding than CONTEXT's wording (full skip, not a stub) |
| `lib/commanded/snapshot_adapter.ex:14-16` | `if Code.ensure_loaded?(Commanded.Aggregates.Aggregate.Snapshotter) do @behaviour ... end` | Yes — CONTEXT cites `:15` |
| `lib/commanded/command_action_mapper.ex:471-486, 488-528, 530-570, 572-608, 610-639` | Five `if Mix.env() == :test do <mock> else <real Ash call> end` blocks at exactly lines 474, 495, 537, 579, 614 | Yes — exact match to CONTEXT.md's five line numbers |
| `lib/commanded/error.ex:349-361` | `from_commanded_error/1`, comment `# Mock implementation for tests` at line 351, but the "mock" is actually the **only** implementation (no test/prod branch) — the comment is stale/misleading, not a real Mix.env() branch | Partially — CONTEXT correctly flags this as needing assessment; the finding is that it's a **misleading comment on real code**, not a functional mock. Recommend: delete the comment, keep the logic (it's a legitimate `%{message: message}` duck-typed fallback), or replace with pattern-matching real `Commanded.Aggregates.ExecutionError`/`Commanded.Aggregates.AggregateError` struct types if those are the actual error shapes Commanded raises — this needs a small spike, not a mechanical deletion |
| `test/test_helper.exs` (full file) | `exclude_tags = if commanded_available? do [:skip] else [:skip, :skip_if_no_commanded] end`, `seed: 0` | Yes — matches D-15 (seed: 0 present) and D-16 (skip logic present) exactly |
| `run_tests.sh` (full file, repo root) | Shell script running `mix test` against 4 disjoint subsets (sections, DSL, transformers excluding `verifier_test`, verifiers including `verifier_test`) — no format/Credo/Dialyzer step | See §`run_tests.sh` Disposition below |

## CommandActionMapper Real Execution Path (Priority 6 — the highest-value new finding)

`lib/commanded/command_action_mapper.ex:471-639` contains four private functions (`execute_create/4`, `execute_update/5`, `execute_destroy/5`, `execute_read/4`) plus `execute_custom/4`. Read directly this session:

- `execute_create/4` (line 477-484, real branch): `Ash.Changeset.new(resource) |> Ash.Changeset.for_action(action_name, params) |> Ash.Changeset.set_context(context) |> Ash.create()`. **Correct, if non-idiomatic**: `Ash.Changeset.new/1` then `for_action/4` is a valid, working Ash 3.x call sequence — not deprecated — but the idiomatic form is `Ash.Changeset.for_create(resource, action_name, params, context: context)` directly [CITED: `ash.hexdocs.pm` Ash.Changeset docs, fetched via WebFetch this session — confirmed `for_action/4`, `for_create/4` signatures and that "calling `new/1` followed by `for_action/4` is not the recommended pattern... the preferred approach is calling `for_create/4`... directly"]. Not a blocker; a style improvement worth doing in the same pass since D-08 already touches every line here.
- `execute_update/5` and `execute_destroy/5` (real branches, lines 498 and 540): both call `resource |> Ash.Query.for_read(:by_id) |> Ash.Query.set_context(context)`. **`Ash.get/3` and `Ash.Query.for_read/2,3` require an actual declared action name — there is no built-in, automatically-available `:by_id` read action in Ash** [CITED: `ash.hexdocs.pm/Ash.html` — `Ash.get/3` docs describe "Get a record by an identifier," a distinct function from `for_read`; the general-purpose docs "do not specify a built-in default read action name... Resources must have configured actions," fetched via WebFetch this session]. Unless every consumer resource happens to define a read action literally named `:by_id` (nothing in this codebase requires, generates, or verifies that), this call will raise `Ash.Error.Invalid.NoSuchAction` (or similar) the instant a real update/destroy command is dispatched against a resource using only Ash's `defaults [:read, ...]` convention (which creates an action named `:read`, not `:by_id`).
- `execute_read/4` (real branch, line 582): calls `Ash.Query.for_read(action_name)` — this one is **correct**, because `action_name` here is the actual declared read-action name passed through from the command/action mapping, not a hardcoded string.

**Concrete recommendation for the planner:** as part of D-08, change the update/destroy lookup from `Ash.Query.for_read(:by_id)` to `Ash.Query.for_read(:read)` (Ash's own default read-action name, created by `defaults [:read, ...]`, matching the test fixture's own `actions do defaults [...] end` block above) — this is a one-line, low-risk fix for both sites (lines 498, 540), and should be done in the same commit as the mock removal because a test written against the mock-removed code will hit this immediately. If a resource author wants a different lookup action, that becomes a legitimate future DSL option, not something to design now. **Flag this fix explicitly in the plan** rather than leaving it implicit in "replace the mocks," since the fix is a behavior change, not a deletion.

`lib/commanded/error.ex:351`'s "Mock implementation for tests" comment is misleading, not functional — the function has no `Mix.env()` branch and is the only implementation. Recommend simply removing the stale comment (or replacing the duck-typed `%{message: message}` match with real `Commanded.Aggregates.ExecutionError` struct pattern-matching once that struct's actual shape is confirmed against the installed `commanded` version — flagged as an Open Question below since verifying Commanded's exact error struct shapes was out of this session's scope).

## Runtime State Inventory

Not applicable — this phase is neither a rename, refactor-of-identifiers, nor migration of stored/live state. It changes compile-time code-generation behavior and test infrastructure. No datastores, external service configs, OS-registered state, secrets, or build artifacts reference the identifiers being touched (guard flags, mock branches) outside this repo's own `lib/`/`test/`/`config/` trees, confirmed by `grep -rn` scoping used throughout this research session finding matches only inside this repository.

## Common Pitfalls

### Pitfall A: The D-19 fixture accidentally depends on test-only libraries

**What goes wrong:** `mix compile` (implicit `MIX_ENV=dev`) fails with an undefined-module error the first time someone adds an `import ExUnit.Assertions` or `alias Mock` to a file placed in a shared `elixirc_paths` directory.
**Why it happens:** `test/support/` is conventionally where Elixir projects put test helpers, and it's tempting to drop the parity fixture there without checking every other file in that directory is also dev-safe.
**How to avoid:** Put the fixture in its own directory (e.g. `test/support/parity/`) containing ONLY an `Ash.Resource` + `Ash.Domain` pair, zero test-framework imports; add only that narrow path (not all of `test/support`) to `elixirc_paths(:dev)`.
**Warning signs:** `mix compile` (no MIX_ENV) failing with `** (CompileError) ... module Mock is not loaded`.

### Pitfall B: `:by_id` read-action assumption (see above) breaks the first real TEST-04 test

**What goes wrong:** A rewritten `command_action_mapper_test.exs` test that dispatches an update/destroy against the new ETS-backed fixture raises an Ash "no such action" error, appearing to be a fixture-configuration mistake when it is actually a library bug.
**How to avoid:** Fix the `:by_id` → `:read` (or equivalent) call before writing the first update/destroy test, per the concrete recommendation above.
**Warning signs:** `%Ash.Error.Invalid{errors: [%Ash.Error.Invalid.NoSuchAction{...}]}` surfacing from what looks like ordinary test setup.

### Pitfall C: Reusing a Commanded application `name:` across `async: true` tests

Already covered above under Anti-Patterns; restated here because it is the exact failure mode TEST-06 exists to prevent, and it is easy to reintroduce accidentally by, e.g., deriving the name from the *test file* rather than a per-test unique integer, which would silently share state across tests within the same file.

### Pitfall D: Assuming `run_tests.sh` is part of the CI contract

See disposition below — treating it as authoritative risks CI silently not running format/Credo/Dialyzer, because the script never invokes them.

## `run_tests.sh` Disposition (Priority 9)

Read in full this session (12 lines, repo root, executable). It runs four `mix test` invocations across disjoint file/tag subsets:

1. `test/commanded/sections/`
2. Four named DSL test files
3. `test/commanded/transformers/ --exclude verifier_test`
4. `test/commanded/verifiers/ --include verifier_test`

Confirmed this session: the `:verifier_test` tag is applied via `@moduletag :verifier_test` in exactly the same 7 files that use `with_mock`/`import Mock` [VERIFIED: `grep -rl "@moduletag :verifier_test" test/` and `grep -rl "with_mock" test/`, both run this session, identical 7-file result sets]. `test_helper.exs` does **not** configure `:verifier_test` as an excluded tag by default — meaning a plain `mix test` (no script) already runs everything `run_tests.sh` runs, in one pass, without the artificial split. The script also never runs `mix format --check-formatted`, `mix credo`, `mix dialyzer`, or a docs build.

**Recommendation:** delete `run_tests.sh` once the `mix check` alias (D-23) lands. It is redundant (plain `mix test` covers its test-running function) and risks becoming a second, drifting "how to run the checks" convention alongside `mix check` — exactly the drift `mix check`'s own rationale (D-23) is meant to prevent. This does not conflict with any locked decision; it is a direct, low-risk cleanup this research recommends the planner include as an explicit task.

## D-17 Triage — verified counts and concrete dispositions

Counts independently verified this session via `grep`/`find` (do not re-derive from CONTEXT.md's prose without checking — one discrepancy found below):

- Total `.exs` test files: **50** [VERIFIED: `find test -name "*.exs" | wc -l`, this session] — CONTEXT.md states "48 existing test files"; this is a minor factual discrepancy (2 files), not material to planning, but the planner should use **50** as the authoritative count and not be surprised when file-count arithmetic doesn't match CONTEXT.md exactly.
- Total `test` declarations: **164** [VERIFIED: `grep -rn "^\s*test " test --include="*.exs" | wc -l`, this session] — matches CONTEXT.md exactly.
- Files whose assertion touches `Code.ensure_loaded?`: **13** [VERIFIED this session] — matches CONTEXT.md exactly. Of these 13, direct inspection this session shows they split into two materially different groups:
  - **6 files check `Code.ensure_loaded?(ResourceWithX)` on the inline DSL-fixture resource itself** (`commands_dsl_test.exs`, `events_dsl_test.exs`, `projections_dsl_test.exs`, `dsl_test.exs`, `command_action_mapping_test.exs`, and one more matching this shape) — this is checking that an ordinary `Ash.Resource` compiled, not a skip-guarded generated module; these tests go on to assert real entity content (fields, identity_field, etc. — confirmed pattern in `.planning/codebase/TESTING.md`'s own excerpt). **Keep these — not part of the Pitfall 5 defect class.**
  - **7 files check `Code.ensure_loaded?`/`Spark.implements_behaviour?` on verifier modules or skip-guarded generated modules with no further content assertion** (`event_handlers_dsl_test.exs` at line 90 checks the transformer module itself is loaded; `verifiers/integration_test.exs` — read in full this session, confirmed **zero** content assertions beyond `Code.ensure_loaded?`/`Spark.implements_behaviour?` across all 9 verifiers — the canonical "contrived test," **delete per D-17**; `verifiers/event_handler_tests.exs` matches the same shape per CONCERNS.md's own prior finding). `transformers/commanded_application_integration_test.exs` (read in full) additionally has its DSL block wrapped in `if Code.ensure_loaded?(Commanded.Application) do ... end` at the resource/domain *definition* level plus `@tag :skip_if_no_commanded` on every test — **these tests have never run** (confirmed: `commanded` is not currently a dependency, so `Code.ensure_loaded?(Commanded.Application)` is false today, so the DSL block that defines `commanded do application do ... end end` doesn't even exist, and the tag excludes the test anyway). **Rewrite**: remove both conditionals (dead by construction post D-01/D-07), keep the domain/resource/test bodies, and give the generated `TestDomain.Application` module a unique test-scoped name per D-15 rather than the fixed compile-time name, to avoid cross-test collisions once these tests actually run.
  - Two files (`transformers/transformer_integration_test.exs`, `transformers/projection_transformer_integration_test.exs`) check `Code.ensure_loaded?` on **command/event/projection** modules — these are generated by transformers that have **no** skip guard (`GenerateCommandModules`, `GenerateEventModules`, `GenerateProjectionModules` are not among the four guarded transformers) and go on to assert real struct field values and function calls — **keep, already load-bearing, no rewrite needed.**
  - `transformers/base_transformer_test.exs` checks `Code.ensure_loaded?` on a module it creates itself via `BaseTransformer.create_module/3` directly in the test, then calls `module_name.test_function()` and asserts the real return value — **keep, already load-bearing.**
- Files using `with_mock`/`import Mock`: **7**, all under `test/commanded/verifiers/`, all mocking `Spark.Dsl.Verifier`'s own `get_persisted`/`get_entities` functions (not Ash or Commanded) to feed fixed `%Command{}`/`%Event{}` structs into the real `verify/1` function [VERIFIED: `test/commanded/verifiers/validate_command_names_test.exs`, read in full this session — confirmed the verifier's *own logic* (`ValidateCommandNames.verify/1`) is the real, unmocked code under test; only the DSL-introspection accessor functions are mocked]. This is architecturally sound (it tests real verifier logic against controlled inputs) but does not exercise full DSL compilation, so it does not satisfy TEST-02's "compile-time" framing on its own. **Recommend: rewrite these 7 using D-14's `Code.compile_string` + `assert_raise` pattern instead** (proving the verifier fires through actual DSL compilation, not through mocked introspection) — this satisfies both TEST-02 and removes the `mock` dependency's last use, resolving the Claude's Discretion item: **the triage outcome supports dropping `{:mock, "~> 0.3.0"}` entirely**, since all 7 of its uses are in this rewritable category and none of the 4 `CommandActionMapper`-touching files use `mock` (they use `Mix.env()` branching instead, per D-08).
- Files touching `CommandActionMapper`: **4** [VERIFIED this session] — matches CONTEXT.md exactly. `command_action_mapper_test.exs` calls `CommandActionMapper.map_to_action(command, resource_module, :create, ...)` with `resource_module = __MODULE__` (the **test module itself**, not an Ash resource) [VERIFIED: read in full this session] — this only "works" today because of the `Mix.env() == :test` mock branch; once D-08 lands this test will crash on `Ash.Changeset.new(__MODULE__)` since the test module isn't an Ash resource. **Rewrite**: point every `map_to_action` call in this file at the real `AshCommanded.TestSupport.Widget` fixture (or equivalent), and change assertions from "the mock echoed back my params" to "a real Ash record now exists with these values." The other 3 files (`error_handling_test.exs`, `context_test.exs`, `parameter_transformer_errors_test.exs`) call `CommandActionMapper.map_to_action` similarly (lines 183/204/220 and 108 respectively) — same rewrite required, scoped to whatever each file is actually testing (error formatting, context propagation, parameter transform errors) rather than assuming they need a full rewrite of unrelated assertions.

**Summary disposition table for the planner:**

| Category | Count | Disposition |
| --- | --- | --- |
| DSL-parsing tests checking the fixture resource compiled + real entity content | ~6 of the 13 `Code.ensure_loaded?` files | Keep as-is |
| Command/event/projection generation tests (unguarded transformers) | 2 of the 13, plus `base_transformer_test.exs` | Keep as-is |
| Verifier-loading-only tests, zero content assertion | `verifiers/integration_test.exs`, `verifiers/event_handler_tests.exs` | Delete |
| Commanded-application test gated by dead-by-construction conditionals + never-run tag | `commanded_application_integration_test.exs` (and its sibling `commanded_application_generator_test.exs`, same `skip_if_no_commanded` pattern, not read in full this session — apply the same disposition after inspection) | Rewrite: remove conditionals, add D-15 unique naming |
| Verifier logic tests using `with_mock` on `Spark.Dsl.Verifier` | 7 files | Rewrite using D-14's `Code.compile_string` pattern; drop `{:mock, ...}` dependency once done |
| `CommandActionMapper`-touching tests | 4 files | Rewrite against real Ash fixture; fix the `:by_id` bug first |

## Cross-Env Compile Parity (D-19, SC2) — concrete mechanism

Given the Anti-Pattern warning above (broad `elixirc_paths(:dev)` inclusion risks breaking `mix compile`), the concrete recommended mechanism:

1. Add a narrow path, e.g. `test/support/parity/`, containing exactly one `Ash.Resource` (with a `commanded` section declaring at least one command and one event) and one `Ash.Domain`, with **no** `ExUnit`/`Mock` references.
2. In `mix.exs`:

   ```elixir
   defp elixirc_paths(:test), do: ["lib", "test/support"]
   defp elixirc_paths(:dev), do: ["lib", "test/support/parity"]
   defp elixirc_paths(_), do: ["lib"]
   ```

   (`test/support/parity` is a subset of `test/support`, included in both; the rest of `test/support` — ETS fixtures with real actions, any `CommandedAppCase` helper — is `:test`-only.)
3. In CI (or a `mix check` step), run a small script/mix task that, for each of `dev` and `test`, compiles with `--warnings-as-errors` and then asserts a **fixed list** of expected generated module names all satisfy `Code.ensure_loaded?/1` — e.g. `AshCommanded.TestSupport.Parity.WidgetAggregate`, `...Commands.CreateWidget`, `...Events.WidgetCreated`, `...Router` (whatever the fixture's resource generates). Comparing a fixed expected list (not a raw `_build/**/*.beam` directory diff) avoids false positives from the many other test-only modules that will legitimately exist only under `:test`.
   [ASSUMED — this is an engineering design derived from the constraints stated in D-19 and the anti-pattern found this session, not a documented recipe from Ash/Spark/Elixir's own docs. Recommend the planner treat this as a first attempt to validate during execution, not a guaranteed-correct design.]

## CI Matrix — building on `.planning/research/STACK.md`, one addition

`.planning/research/STACK.md`'s CI Matrix section (lines 127-185) already has HIGH-confidence, live-verified reasoning for the Elixir/OTP pairings, the primary-cell choice (1.18/OTP 27, matching `core`), and why `ash-project`'s shared reusable workflow can't be reused from `accountex-org`. Do not duplicate that reasoning — reuse it directly.

**One addition this session found, relevant to D-25:** `erlef/setup-beam`'s `action.yml` declares `install-hex: true` and `install-rebar: true` as defaults [CITED: `raw.githubusercontent.com/erlef/setup-beam/main/action.yml`, fetched via WebFetch this session] — meaning **CI itself likely does not need an explicit `mix local.rebar --force` step** the way a bare-metal developer machine does; `erlef/setup-beam@v1` already runs the equivalent internally. D-25's explicit CI step (`CI calls mix local.rebar --force before deps.get`) is therefore likely redundant defense-in-depth rather than a fix for a real CI gap — harmless to keep (matches the locked decision), but the planner should not be surprised if this step appears to do nothing in a passing CI run, and should not spend debugging time on it if CI passes without it. The **developer-machine** side of D-25 (the `mix setup` alias) remains necessary regardless, since a fresh local machine may not have rebar3 and has no `erlef/setup-beam` equivalent.

## Dialyzer Specifics (D-22)

Exact `.dialyzer_ignore.exs` format [CITED: `github.com/jeremyjh/dialyxir` README, fetched via WebFetch this session]:

```elixir
# .dialyzer_ignore.exs
[
  {"lib/some_file.ex", :no_return},                              # {file, warning_type}
  {"lib/some_file.ex", "Function :foo.bar/1 does not exist."},   # {file, warning_description}
  ~r/my_file\.ex.*my_function.*no local return/                  # regex against full warning text
]
```

Referenced from `mix.exs`:

```elixir
def project do
  [
    dialyzer: [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_file: {:no_warn, "priv/plts/project.plt"}
    ]
  ]
end
```

**Seed the file** by running `mix dialyzer --format ignore_file` (groups warnings by file+type) or `--format ignore_file_strict` (includes full descriptions for tighter matching) once Dialyzer's first real run completes, then commit the output verbatim as the starting `.dialyzer_ignore.exs`, exactly matching D-22's intent. **CI caching:** key the PLT cache on `mix.lock` hash + the primary cell's Elixir/OTP versions, using the `plt_file` path above as the `actions/cache` `path:` target — this is what makes "one PLT to build and cache instead of three" (D-20) concrete.

## Security Domain

`security_enforcement` is enabled (config default) at ASVS level 1, but this phase's subject — a Spark DSL code-generation library with no HTTP endpoints, no authentication, no session management — makes most ASVS categories not applicable in the usual web-app sense. Applying them honestly:

| ASVS Category | Applies | Standard Control |
| --------------- | --------- | ----------------- |
| V2 Authentication | No | This library has no authentication surface; command/action authorization is the consuming application's Ash policy layer, unaffected by this phase |
| V3 Session Management | No | No session concept in this library |
| V4 Access Control | Partial | Existing, pre-phase-1 gap (CONCERNS.md): command-dispatch middleware is optional/per-command and can be bypassed; the missing `ValidateCommandNameConflict` verifier (documented in CLAUDE.md, absent in code) means a command name could theoretically collide with an Ash action name. **Both are explicitly out of scope for Phase 1** (QUAL-06 is Phase 2) — Phase 1 must not silently "fix" these while touching adjacent code, since CONTEXT.md scopes this phase to honesty-of-tests, not new verifiers |
| V5 Input Validation | Yes | `ParameterValidator` middleware (existing) is the validation layer; this phase's `CommandActionMapper` fix (D-08) must not weaken it — the real Ash action call (`Ash.Changeset.for_action`) itself re-validates via Ash's own attribute constraints, which is a secondary, defense-in-depth validation layer this phase newly makes real (it was previously mocked, i.e., previously **not exercised at all**) |
| V6 Cryptography | No | No cryptographic operations in this library |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command name shadows an Ash action name, allowing dispatch through an unintended path | Tampering / Elevation of Privilege | Missing verifier (`ValidateCommandNameConflict`) — explicitly deferred to Phase 2 (QUAL-06); Phase 1 should not attempt this fix, only note it does not regress further |
| A test-only mock silently replacing real authorization/validation logic gives false confidence that input validation works | Tampering (indirect — via untested code shipping) | This is precisely what Phase 1 fixes: making `CommandActionMapper`'s real Ash execution path (which re-validates via Ash's own action constraints) actually run in tests, rather than a mock that bypasses all validation silently |

## Code Examples

### Verified pattern: real `execute_create/4` path (already correct, kept for reference)

```elixir
# lib/commanded/command_action_mapper.ex:477-484, read this session — the "else" branch, becomes the ONLY branch after D-08
changeset = Ash.Changeset.new(resource)
changeset = Ash.Changeset.for_action(changeset, action_name, params)
changeset = Ash.Changeset.set_context(changeset, context)

case Ash.create(changeset) do
  {:ok, _} = success -> success
  {:error, error} -> {:error, error}
end
```

### Recommended fix for `execute_update/5` and `execute_destroy/5` (the `:by_id` bug)

```elixir
# BEFORE (lib/commanded/command_action_mapper.ex:498, :540 — read this session):
query = resource |> Ash.Query.for_read(:by_id) |> Ash.Query.set_context(context)

# AFTER (recommended):
query = resource |> Ash.Query.for_read(:read) |> Ash.Query.set_context(context)
```

Matches Ash's own `defaults [:read, ...]` convention, which is what the D-12/D-13 test fixture (and, per the "genericity" project constraint, any generic consumer resource following Ash's documented getting-started pattern) will actually declare.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
| -------------- | ------------------ | --------------- | -------- |
| `Ash.Changeset.new/1` then `for_action/4` | `Ash.Changeset.for_create/4` (or `for_update`/`for_destroy`) directly | Ash 3.x's documented preferred style [CITED: `ash.hexdocs.pm` Changeset docs, this session] | Not a breaking change — the old form still works; purely idiomatic, worth adopting in the same D-08 pass since every line is already being touched |
| `spark ~> 2.3` | `spark ~> 2.6` | Ash's own `mix.exs` requires `>= 2.6.0` as of current `main` | Already captured by D-05; re-verified this session |

**Deprecated/outdated:** none of the packages in this phase's scope have documented breaking changes between the currently-pinned and currently-latest versions (re-confirming `.planning/research/STACK.md`'s own CHANGELOG-grep findings, not re-derived independently this session).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
| --- | ------- | --------- | --------------- |
| A1 | `test_coverage: [tool: ExCoveralls]` + `preferred_cli_env` is the correct, current ExCoveralls mix.exs config shape | Standard Stack | Low — boilerplate, easily corrected if `mix coveralls` fails to run; would surface immediately in CI |
| A2 | `use Ash.Resource, data_layer: Ash.DataLayer.Ets` + `actions do defaults [...] end` + `attribute ..., public?: true` is the exact current Ash 3.x minimal-resource shape | Pattern 2 | Low-medium — if `public?: true` syntax has changed, `mix compile` will fail immediately and loudly on the fixture, not silently |
| A3 | Cross-env compile-parity mechanism (fixed expected-module-name list, compared under `MIX_ENV=dev`/`test`) is a workable design for D-19 | Cross-Env Compile Parity | Medium — this is original engineering design, not a documented recipe; if module names generated under `:dev` differ unexpectedly from `:test` for reasons unrelated to the skip guards (e.g., macro hygiene differences), the check could give a false failure; recommend a spike/smoke-test early in phase execution |
| A4 | `Commanded.Aggregates.ExecutionError`/similar error struct shapes referenced for `error.ex:351`'s cleanup are real Commanded structs | CommandActionMapper Real Execution Path | Low-medium — not independently verified against the installed `commanded` version's actual error modules this session; if wrong, the existing duck-typed `%{message: message}` fallback is a safe, working default to fall back to |

**If this table is empty:** not applicable — see entries above.

## Open Questions

1. **Does `use Commanded.Event.Handler, application: SomeModule` accept an application-name override at `start_link/1` call time, analogous to `Commanded.Application`'s own `name:` override?**
   - What we know: `Commanded.Application.start_link(name: unique_atom)` is documented and confirmed this session. Event handlers/projectors generated by this library hardcode `application: <fixed module name>` at compile time (confirmed by reading `generate_projector_modules.ex` and `generate_event_handler_modules.ex` this session).
   - What's unclear: whether a handler process itself can be started against a differently-named running application instance, or whether it's permanently bound to the literal module name baked in at compile time.
   - Recommendation: for Phase 1, sidestep this entirely by testing projector/handler `handle/2` functions directly (Pattern 3 above) rather than starting them as subscribed processes — this satisfies TEST-03 without needing an answer. Defer the "real subscription, real named instance" question to Phase 5 (FOUND-05, projector auto-discovery/supervision), where it's already in scope.

2. **Exact error-struct shapes Commanded raises, for `error.ex:351`'s misleading-comment cleanup.**
   - What we know: `from_commanded_error/1` currently does generic `%{message: message}` duck-typing, which works for anything with a `:message` key.
   - What's unclear: whether real Commanded errors (from `Commanded.Aggregates.ExecutionError`, a dispatch timeout, etc.) always have a `:message` key, or whether some have differently-shaped fields the duck-typed match would mishandle.
   - Recommendation: budget a small spike — dispatch a command that deliberately fails (e.g., aggregate precondition rejection) through a real `commanded` app in a throwaway script, inspect the actual error struct, and confirm/adjust `from_commanded_error/1` accordingly. Low risk either way since the duck-typed fallback already handles the unknown case.

3. **Discrepancy: CONTEXT.md states 48 test files; this session counted 50.**
   - What we know: `find test -name "*.exs" | wc -l` returns 50, this session.
   - What's unclear: whether CONTEXT.md's count excluded 2 files for a specific reason (e.g., not counting `test_helper.exs` and one other), or was simply approximate.
   - Recommendation: not material to planning — use 50 as the ground truth if the plan needs an exact count anywhere (e.g., a "triage all N files" checklist).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
| ------------ | ------------ | ----------- | --------- | ---------- |
| Elixir | Everything | ✓ (assumed local dev machine matches `core`'s 1.18.4 per PROJECT.md; not independently probed on this machine this session) | 1.18.4 (per `core`, per project docs) | — |
| Erlang/OTP | Everything | ✓ (assumed 27.3 per `core`) | 27.3 | — |
| rebar3 | `mix deps.get` (for `:telemetry` and other rebar3-built deps) | ✗ today, per D-25's own stated finding (`Could not find "rebar3"` error) — this is the documented, locked reason D-25 exists | — | `mix setup` alias runs `mix local.rebar --force` first |
| Docker / Postgres | Not needed this phase | N/A | — | D-12 explicitly avoids this (ETS, not Postgres, for Phase 1) |
| GitHub Actions (`erlef/setup-beam`, `actions/cache`) | CI (D-20) | Assumed available (standard, public GitHub Actions) | `@v1` / `@v4` per STACK.md's matrix | — |

**Missing dependencies with no fallback:** none identified for this phase's scope — rebar3's absence has an explicit, locked fallback (D-25).
**Missing dependencies with fallback:** rebar3 (see above).

## Validation Architecture

### Test Framework

| Property | Value |
| ---------- | ------- |
| Framework | ExUnit (bundled with Elixir; no version pin beyond the Elixir version itself) |
| Config file | `mix.exs` (`test_coverage`, `preferred_cli_env` — none exist yet; added by D-18) |
| Quick run command | `mix test test/commanded/command_action_mapper_test.exs` (or any single touched file) |
| Full suite command | `mix check` (D-23 alias — format, Credo, compile --warnings-as-errors, test, Dialyzer, docs, once added) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
| -------- | ---------- | ----------- | ------------------- | ------------- |
| QUAL-01 | `mix deps.get` resolves `:commanded`/`:eventstore` without consumer supplying them | smoke | `rm -rf deps _build && mix deps.get && mix compile --warnings-as-errors` | ✅ (mix.exs exists, edit in place) |
| QUAL-02 | No `IO.puts`/`IO.inspect` in `lib/` | static | `grep -rn "IO.puts\|IO.inspect" lib/` returns nothing; `mix credo` blocks on `Warning.IoInspect`/`Warning.IExPry` | ❌ Wave 0 — `.credo.exs` doesn't exist yet |
| TEST-01 | No `Mix.env()` branch in `lib/` | static + unit | `grep -rn "Mix.env()" lib/` returns nothing; existing `command_action_mapper_test.exs` rewritten to assert real Ash records | ❌ Wave 0 — rewrite required, see D-17 triage |
| TEST-02 | Invalid DSL rejected with specific message | unit | `mix test test/commanded/verifiers/` (post-rewrite, using `Code.compile_string` + `assert_raise`) | ❌ Wave 0 — 7 files need rewrite |
| TEST-03 | Generated aggregate/projector/router/event-handler exercised as real modules | unit | New tests per Pattern 3 above | ❌ Wave 0 — `test/support/` fixtures don't exist |
| TEST-04 | Real Ash create/update/destroy, no mocks | unit | `mix test test/commanded/command_action_mapper_test.exs` (post-rewrite) | ❌ Wave 0 — fixture + `:by_id` fix required first |
| TEST-06 | No event-store leakage across async tests | unit/integration | New dispatch-level tests per D-15 pattern; `mix test --seed 0` removed, run with default random seed repeatedly in CI to catch order-dependence | ❌ Wave 0 — `test/support/commanded_app_case.ex` (or inline equivalent) doesn't exist |
| REPO-03/04/05 | Full CI gate list green | integration | `mix check` locally; `.github/workflows/ci.yml` in CI | ❌ Wave 0 — CI is entirely greenfield |

### Sampling Rate

- **Per task commit:** the single touched test file (`mix test path/to/file.exs`)
- **Per wave merge:** `mix check` (once the alias exists) or the individual gate commands until it does
- **Phase gate:** `mix check` fully green, plus the cross-env compile-parity check (D-19) run explicitly, before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/support/parity/*.ex` — D-19 fixture, dependency-free, dual `elixirc_paths`
- [ ] `test/support/test_domain.ex` + `test/support/widget.ex` (or equivalent names) — ETS-backed shared fixture for TEST-03/04, covers REQ TEST-03, TEST-04
- [ ] `.credo.exs` — checked in, default strictness, covers QUAL-02 enforcement
- [ ] `.dialyzer_ignore.exs` — seeded after first real `mix dialyzer` run, covers REPO-05
- [ ] `.github/workflows/ci.yml` — greenfield, covers REPO-04/05
- [ ] `mix.exs` aliases: `setup`, `check` — covers D-23, D-25
- [ ] Framework installs: `{:credo, ...}`, `{:dialyxir, ...}`, `{:excoveralls, ...}` — `mix deps.get` after `mix.exs` edit

Note: no pre-existing test infrastructure covers any of these — the phase is explicitly building the infrastructure other phases will assume exists.

## Sources

### Primary (HIGH confidence — verified live this session)

- `hex.pm/api/packages/{ash,spark,commanded,eventstore,commanded_eventstore_adapter,credo,dialyxir,excoveralls,usage_rules}` — queried live via `curl` this session; every version number in §Standard Stack comes from this call
- `raw.githubusercontent.com/ash-project/ash/main/mix.exs` — fetched this session, confirms `{:spark, ">= 2.6.0"}` at line 385
- This repository's own source, read directly this session: `lib/commanded/command_action_mapper.ex` (lines 440-641), `lib/commanded/error.ex` (lines 330-368), `lib/commanded/transformers/generate_aggregate_module.ex` (lines 1-260), `lib/commanded/transformers/generate_projector_modules.ex` (lines 1-60, 185-215), `lib/commanded/transformers/generate_main_router_module.ex` (lines 180-230, 335-365), `lib/commanded/transformers/generate_event_handler_modules.ex` (lines 85-230), `lib/commanded/transformers/generate_commanded_application.ex` (full file), `lib/commanded/transformers/base_transformer.ex` (lines 1-40), `lib/commanded/snapshot_adapter.ex` (full file), `mix.exs`, `mix.lock`, `test/test_helper.exs`, `run_tests.sh`, and 8 individual test files listed inline above
- `.planning/phases/01-build-integrity/01-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/research/STACK.md`, `.planning/research/PITFALLS.md`, `.planning/codebase/TESTING.md`, `.planning/codebase/CONCERNS.md` — all required reading, read in full this session

### Secondary (MEDIUM confidence — official docs/source fetched via WebFetch/WebSearch this session)

- `ash.hexdocs.pm/Ash.html`, `ash.hexdocs.pm/Ash.Changeset.html` — `Ash.get/3`, `Ash.read_one/2`, `Ash.Changeset.new/1`/`for_action/4`/`for_create/4` signatures and current-idiom guidance
- `github.com/ash-project/ash/blob/main/lib/ash/data_layer/ets/ets.ex` (fetched via WebFetch) — `ets do private? / table end` schema and `private?`'s process-scoping semantics
- `commanded.hexdocs.pm/Commanded.Application.html` (fetched via WebFetch) — `name:` option on `start_link/1`, `application:` dispatch option
- `github.com/commanded/commanded/blob/master/lib/commanded/event_store/adapters/in_memory.ex` (fetched via WebFetch) — confirms event-store process naming is derived from the `application` value, i.e., per-unique-name isolation without manual `reset!`
- `github.com/rrrene/credo` default `.credo.exs` (fetched via WebFetch) — confirms `Warning.IoInspect`/`Warning.IExPry` are default-enabled checks
- `github.com/jeremyjh/dialyxir` README (fetched via WebFetch) — `.dialyzer_ignore.exs` format, `mix dialyzer --format ignore_file`, `plt_file` config
- `raw.githubusercontent.com/erlef/setup-beam/main/action.yml` (fetched via WebFetch) — `install-hex`/`install-rebar` default to `true`

### Tertiary (LOW confidence — WebSearch summaries, training-knowledge patterns not independently re-verified against a live source this session)

- ExCoveralls `mix.exs` `test_coverage`/`preferred_cli_env` config shape (A1 in Assumptions Log)
- Ash 3.x minimal resource+domain pattern for `Ash.DataLayer.Ets` (`public? true`, `defaults [...]`) (A2 in Assumptions Log) — cross-checked against WebSearch results referencing `ash-hq.org`/hexdocs but not read verbatim from a live current-version page this session

## Metadata

**Confidence breakdown:**

- Standard stack (versions): HIGH — every version number re-verified live against hex.pm's API this session, not carried over from training data or from STACK.md without re-check
- Code-site findings (guard/mock locations, `:by_id` bug, `run_tests.sh`, D-17 triage counts): HIGH — every claim in these sections is backed by a direct `Read`/`grep`/`find` this session, with exact line numbers and verbatim quotes where load-bearing
- Ash/Commanded API surfaces (ETS data layer, Changeset/Query calls, per-test app isolation): MEDIUM-HIGH — fetched from official docs/source this session via WebFetch, but summarized by an intermediate model rather than read as raw text by this agent; treat exact syntax as CITED, not VERIFIED, and spot-check during execution
- CI/cross-env-parity design (D-19 mechanism, `run_tests.sh` disposition, ExCoveralls config): MEDIUM — sound engineering reasoning built on verified constraints, but original design work, not a documented recipe; budget a small spike if it doesn't work as described

**Research date:** 2026-09-12
**Valid until:** ~14 days for the dependency-version table (fast-moving hex.pm ecosystem, matches STACK.md's own posture); ~60 days for the code-site findings (these only change if someone edits the named files, which is exactly what this phase will do — re-verify line numbers after D-06/D-07/D-08 land, before Phase 2 planning)
