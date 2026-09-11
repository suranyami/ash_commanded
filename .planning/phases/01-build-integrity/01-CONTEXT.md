# Phase 1: Build Integrity - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning

<domain>

## Phase Boundary

Every test in the suite can fail for a real reason, on a current, CI-enforced toolchain.

This phase delivers **honesty**, not capability. No new DSL surface, no new library feature. It
removes the three independent mechanisms that currently make the test suite incapable of detecting
a defect (`Mix.env()` branches, `Application.get_env` skip knobs, `Code.ensure_loaded?` stub
fallbacks), replaces `CommandActionMapper`'s hardcoded mock returns with real Ash execution, and
puts a CI pipeline and current toolchain underneath the result.

Requirements: QUAL-01, QUAL-02, REPO-03, REPO-04, REPO-05, TEST-01, TEST-02, TEST-03, TEST-04,
TEST-06.

**Not in this phase:** transformer ordering and the Domain/Resource boundary (Phase 2), any new DSL
capability (Phases 3-6), consumer-facing `usage-rules.md` and `AGENTS.md` (Phase 7).

</domain>

<decisions>

## Implementation Decisions

### Dependency Declaration

- **D-01:** `:commanded` is declared as a **hard runtime dependency** in `mix.exs` — not `optional:
  true`, not `only: [:dev, :test]`. Every consumer of this library needs Commanded, and the
  generated AST (`use Commanded.Event.Handler`, `use Commanded.Commands.Router`) depends on it
  unconditionally. This also satisfies SC1 more directly than the criterion's wording assumes: the
  consumer does not need to *supply* Commanded because the library brings it.
  **Constraint:** the version chosen must remain resolvable alongside `core`'s own Commanded 1.4.8.
  — **Reversibility:** costly — moving a hard dep to optional after publish breaks every consumer
  who relied on transitive installation.

- **D-02:** `:eventstore` (Postgres-backed persistence, reached via `commanded_eventstore_adapter`)
  is declared **`optional: true`**. It is visible in hex metadata but not forced on consumers, so a
  consumer running `Commanded.EventStore.Adapters.InMemory` or a third-party adapter does not
  inherit Ecto, Postgrex and EventStore migrations. ash_commanded's own test suite still resolves it,
  which Phase 5's PROJ-03 Postgres integration test and Phase 7's Postgres example both require.

- **D-03:** Remove Sourceror and Igniter? **No — both stay**, versions bumped with the rest. (Both
  currently have zero references in `lib/` or `test/`, and there are no `mix/tasks/`. Retained
  deliberately, presumably against a future Igniter-based installer.)

- **D-04:** Add `{:usage_rules, "~> 1.2", only: [:dev]}` and sync **Spark's and Ash's own**
  `usage-rules.md` into this repo, so an agent working on AshCommanded is told how Spark expects
  transformers and verifiers to behave. This is *consuming* upstream rules — distinct from REPO-01's
  *production* of AshCommanded's own usage rules for downstream consumers, which stays in Phase 7.

- **D-05:** Version-bound style is **permissive bounds, current lock**: declare `ash ~> 3.0` and
  `spark ~> 2.6` (the floor Ash requires), while `mix.lock` moves to current releases so CI tests
  against them. The `~>` major is the compatibility claim; the lock is what is verified. Required by
  the constraint that `core` must resolve its own versions freely.

### Removing the Dishonesty Mechanisms

- **D-06:** Delete **all four** `Application.get_env(:ash_commanded, :skip_*_module_creation)` knobs
  outright — `:skip_aggregate_module_creation`, `:skip_projector_module_creation`,
  `:skip_router_module_creation`, `:skip_event_handler_module_creation`. `BaseTransformer.create_module/3`
  is called unconditionally. No replacement flag, global or otherwise. TEST-01 requires test and
  production to behave identically; a knob that can make them differ is the same defect with a
  different switch, and nothing in `config/` or `test/` sets any of them today.

- **D-07:** Delete **all six** `Code.ensure_loaded?(Commanded*)` stub-generation branches. With
  Commanded a hard dependency these are dead by construction. Sites:
  `generate_projector_modules.ex:196`, `generate_main_router_module.ex:216` and `:347`,
  `generate_event_handler_modules.ex:214`, `generate_commanded_application.ex:244`, and
  `snapshot_adapter.ex:15` (whose `@behaviour Commanded.Aggregates.Aggregate.Snapshotter` becomes
  unconditional, which also makes it Dialyzer-checkable). This closes a failure mode the requirements
  do not name: `generate_main_router_module.ex:216`'s else-branch emits a router whose `dispatch/1`
  is `{:ok, command}` — a real-looking module that accepts every command and dispatches nothing.

- **D-08:** Replace the five `Mix.env() == :test` mock returns in `CommandActionMapper`
  (`:474`, `:495`, `:537`, `:579`, `:614`) with the real Ash execution path. Note a sixth,
  uncounted site: `error.ex:351` carries a `# Mock implementation for tests` comment on
  `from_commanded_error/1` — assess it in the same pass.

### Logging (QUAL-02)

- **D-09:** `snapshot_store.ex:111` becomes `Logger.error` and **keeps its `:error` return**. The
  public contract of `get_snapshot/2` does not change; callers are unaffected. The bare `rescue e`
  that swallows all exception classes is **left as-is** and recorded as a concern for the snapshot
  store rewrite (SNAP-01..03, Phase 4) — not fixed opportunistically here.

- **D-10:** The three `IO.inspect` calls in `base_middleware.ex:18,25,31` are inside the
  `@moduledoc` example code block, **not executable code**. They are rewritten to use `Logger.debug`,
  matching what `logging_middleware.ex:102-105` already does — the documented example currently
  teaches the opposite of the library's own practice. They must change regardless, because SC1's
  check is a `grep` over `lib/` that does not distinguish a docstring from a function body.

- **D-11:** QUAL-02 is kept true by **Credo, blocking** — `Credo.Check.Warning.IoInspect` (on by
  default) plus `Credo.Check.Warning.IExPry`. No bespoke grep test in the suite; SC1's grep remains
  the belt-and-braces check for the docstring case Credo does not scan.

### Test Infrastructure

- **D-12:** Ash data layer for tests is **`Ash.DataLayer.Ets` now, AshPostgres added in Phase 5**
  alongside PROJ-03 (which already demands a Postgres integration test). ETS ships inside Ash core —
  no new dependency, no Postgres service in CI, no migrations — and keeps `mix test` runnable from a
  fresh clone, which the CI decisions depend on.
  **Note for planning:** the Ash data layer (read-model persistence) and the Commanded event store
  adapter (event persistence) are independent axes. Phase 1 needs only the first.

- **D-13:** Add `elixirc_paths(:test)` (absent today) and use a **hybrid fixture layout**: a shared
  domain plus fully-formed resources in `test/support/` for action-execution tests (TEST-03,
  TEST-04), compiled once; inline `defmodule` resources retained for DSL-shape and rejection tests
  (TEST-02), because each deliberately declares a *different* malformed DSL and cannot share a
  fixture.

- **D-14:** Compile-time rejection tests (TEST-02) use **`Code.compile_string` inside
  `assert_raise Spark.Error.DslError, ~r/.../`**, with the regex naming the distinguishing part of
  the message (offending command name, duplicate field, unknown action) rather than the full string.
  Fails loudly if the verifier is deleted — no error raised at all — while surviving Spark reformatting
  its error envelope across the version bumps REPO-03 makes. Bad DSL never sits in a compiled file.
  (This matches the pattern documented at `.planning/research/PITFALLS.md:146`, which notes Ash's own
  test suite uses it throughout.)

- **D-15:** Test isolation (TEST-06 / SC5): each test that dispatches starts its **own Commanded
  application under a generated unique name**, with its own `InMemory` store instance, torn down in
  `on_exit`. No shared named process, so `async: true` is preserved — which matters because the suite
  gets substantially slower once every generated module really compiles. **`seed: 0` is dropped** so
  ExUnit shuffles and order-dependence surfaces as a failure instead of hiding.

- **D-16:** `test_helper.exs` is reduced to `ExUnit.start()` with **no default exclusions**. Both
  `:skip_if_no_commanded` (now permanently false — remove the tag from all 9 tests, which have never
  run) and `exclude: [:skip]` are deleted. A test that cannot pass must be fixed or deleted, never
  tagged out of sight.

- **D-17:** Existing 48 test files (164 `test` declarations) are triaged as **delete contrived,
  rewrite load-bearing**. Establish a green baseline first, then treat the suite as a liability: a
  test asserting `Code.ensure_loaded?(Mod)` against a module the transformer was skipping proved
  nothing and is deleted, not repaired. Review set: the 13 files whose assertion is
  `Code.ensure_loaded?`, the 7 files using `with_mock`, the 4 touching `CommandActionMapper`. Tests
  covering real behaviour (Error formatting, parameter transformation, DSL entity extraction) stay
  and are fixed. Outcome is fewer tests that mean more.

- **D-18:** Add **ExCoveralls, report-only, no threshold**. Publishes an honest baseline measured
  against a suite where tests can actually fail. No gate in Phase 1, because D-17 deliberately
  deletes fiction tests and the number should be allowed to drop before it climbs. A threshold is set
  later against a real starting point. (This is a deliberate, scoped exception to the standing 80%
  coverage rule.)

- **D-19:** SC2 (test/dev module parity) is demonstrated by a **dev-visible fixture plus a cross-env
  compile check in CI**. One minimal resource+domain sits in a path `elixirc_paths` includes for both
  `:dev` and `:test`; CI compiles under each environment and compares the generated module set.
  **Planning note:** generated modules only exist when a *resource* compiles, and every resource
  today lives under `test/` — so `_build/dev` currently contains no generated modules at all. This
  fixture is what makes the comparison possible. It must be domain-neutral (published-package
  constraint).

### CI and Toolchain

- **D-20:** Matrix shape is **fan out tests, pin slow gates to primary**. `mix test` and
  `mix compile --warnings-as-errors` run across all three Elixir/OTP pairs (1.18, 1.19, 1.20 on their
  supported OTP releases). Format check, Credo, Dialyzer, docs build and coverage run once on the
  primary cell — **1.18 / OTP 27**, matching `core`. One PLT to build and cache instead of three.

- **D-21:** Credo runs at **default strictness, blocking** on PRs, with a checked-in `.credo.exs`.
  Not `--strict`: promoting every readability check to a failure would fire on the 861-line
  `GenerateAggregateModule` and 640-line `CommandActionMapper` that Phases 4 and 6 are already
  scheduled to decompose. Anything Credo flags in Phase 1 is fixed or explicitly disabled in
  `.credo.exs` **with a stated reason** — no silent tolerance.

- **D-22:** Dialyzer is **blocking, with a seeded ignore file**. Add `dialyxir`, run once, commit
  `.dialyzer_ignore.exs` capturing exactly what exists today, then block on anything new. Existing
  debt is recorded rather than fixed in this phase; the ignore file is a visible list later phases
  shrink. Rationale: the finding count is genuinely unknown (Spark generates a large macro surface,
  and `snapshot_adapter.ex`'s newly-unconditional `@behaviour` adds more), and Phase 1 blocks twelve
  downstream phases.

- **D-23:** Add a **`mix check` alias** running exactly the REPO-05 gate list, so a developer or
  agent reproduces CI locally with one command — matching the habit `core` establishes. CI invokes the
  alias where practical rather than restating steps, so the two cannot drift.

- **D-24:** The docs gate runs **`mix gen.docs`**, not plain `mix docs` — it regenerates Spark cheat
  sheets before building, catching a DSL option that breaks cheat-sheet generation.
  **Planning note:** `spark.cheat_sheets` is currently configured for
  `--extensions AshCommanded.Commanded.Dsl` only, not `DomainDsl`. Phase 7's DOCS-04 requires both;
  Phase 1 only needs the gate to pass as currently configured.

- **D-25:** Bootstrap: add a **`mix setup` alias** (`local.hex --force`, `local.rebar --force`,
  `deps.get`, `deps.compile`), and CI calls `mix local.rebar --force` before `deps.get`. Rationale:
  `mix deps.get` fails on a clean machine today with
  `Could not find "rebar3", which is needed to build dependency :telemetry` — so SC1's literal
  command is false on a genuinely fresh clone. README documents `mix setup` then `mix check`.

- **D-26:** `--warnings-as-errors` debt is cleared as its own task **inside** this phase, sized once
  `mix compile` actually runs. It is not deferred and not used to gate other tasks.

### Sequencing

- **D-27:** The uncommitted `fix-application-generation` work (88 insertions / 48 deletions across 8
  files) is **committed as-is first**, before Phase 1 edits begin. Three of those files —
  `generate_aggregate_module.ex`, `generate_event_handler_modules.ex`,
  `generate_projector_modules.ex` — carry `Mix.env()` guards Phase 1 must delete, so the overlap is
  unavoidable. Committing first preserves the work, gives a reviewable baseline, and keeps Phase 1's
  diff legible (guard deletions readable without DomainDsl changes tangled in). Phase 2 still owns
  finishing the Domain/Resource split. Two DomainDsl commits (`a956434`, `b259992`) are already on the
  branch.

### Claude's Discretion

- Whether `{:mock, "~> 0.3.0", only: [:test]}` survives the D-17 triage. It is used in 7 test files;
  if all of them are deleted or rewritten to use real Ash execution, the dependency goes. Decide from
  the triage outcome, not in advance.
- Exact Elixir/OTP pairings for the three matrix cells (which OTP each Elixir version is tested on).
- Whether CI runs on PRs only or also on push to `main`, and the dependency cache key (`mix.lock`).
- Whether the `test/support` ETS tables are `private?: true` per-process or named.
- Whether a `test/support` helper wraps unique-named Commanded app startup, or each test does it
  inline.
- Precise wording and content of `.credo.exs` disables and `.dialyzer_ignore.exs` entries.

</decisions>

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope and requirements

- `.planning/REQUIREMENTS.md` — the 10 Phase 1 requirements (QUAL-01, QUAL-02, REPO-03, REPO-04,
  REPO-05, TEST-01..04, TEST-06) and the traceability table
- `.planning/ROADMAP.md` §"Phase 1: Build Integrity" — goal, the five success criteria SC1-SC5, and
  the note naming the four transformer guard sites and the five `CommandActionMapper` mock sites
- `.planning/ROADMAP.md` §"Ordering Constraints" — why Phase 1 is a hard blocker for all twelve
  downstream phases
- `.planning/PROJECT.md` §Constraints — the Elixir/OTP support window, the `core`-compatibility
  constraint on dependency versions, and the genericity requirement on published examples/tests

### Existing-code analysis

- `.planning/codebase/CONCERNS.md` — the known-debt inventory this phase draws from
- `.planning/codebase/TESTING.md` — current test conventions, file layout, and the `test_helper.exs`
  exclusion machinery being removed
- `.planning/codebase/STACK.md` — current declared and locked dependency versions

### Research (directly load-bearing for this phase)

- `.planning/research/PITFALLS.md` §Pitfall 5 (and line 146) — the exact
  `Code.compile_string` + `assert_raise Spark.Error.DslError` pattern adopted in D-14, with the
  explanation of why `defmodule` inside an anonymous function defers transformer execution to test
  runtime. Also line 98: every verifier needs both an accepting and a rejecting test.
- `.planning/research/STACK.md` §CI — the reasoning behind the matrix shape in D-20, including why
  `ash-project`'s shared reusable workflow cannot be used from `accountex-org`
- `.planning/research/STACK.md:213` — why `:usage_rules` belongs as a `only: [:dev]` dependency here
  (D-04) and why no `usage_rules:` config key belongs in this repo's `mix.exs`
- `.planning/research/ARCHITECTURE.md` §"Spark anatomy" and §Patterns — `Spark.InfoGenerator`, the
  `{:spark_behaviour, _}` / `{:spark_function_behaviour, _, _}` escape-hatch types, transformer
  ordering semantics, and the one-way Domain→Resource boundary

### Spark DSL authoring (upstream)

- <https://spark.hexdocs.pm/writing-extensions.html> — Transformers → Persisters → Verifiers ordering
  contract; "prefer verifiers over transformers when you only need to validate"; introspection
  belongs in a `ModuleName.Info` module
- <https://hexdocs.pm/spark/get-started-with-spark.html> — section/entity structure fundamentals
- <https://hexdocs.pm/spark/Spark.Dsl.Extension.html> — extension declaration API

### Specific code sites named in decisions

- `lib/commanded/command_action_mapper.ex:474,495,537,579,614` — the five mock returns (D-08)
- `lib/commanded/error.ex:351` — sixth, uncounted mock site (D-08)
- `lib/commanded/transformers/generate_aggregate_module.ex:140` — skip knob (D-06)
- `lib/commanded/transformers/generate_projector_modules.ex:112,196` — knob and stub (D-06, D-07)
- `lib/commanded/transformers/generate_main_router_module.ex:127,216,347` — knob and two stubs
  (D-06, D-07)
- `lib/commanded/transformers/generate_event_handler_modules.ex:98,214` — knob and stub (D-06, D-07)
- `lib/commanded/transformers/generate_commanded_application.ex:244` — stub (D-07)
- `lib/commanded/snapshot_adapter.ex:15` — conditional `@behaviour` (D-07)
- `lib/commanded/snapshot_store.ex:111` — live `IO.puts` in a bare rescue (D-09)
- `lib/commanded/middleware/base_middleware.ex:18,25,31` — `IO.inspect` inside `@moduledoc` (D-10)
- `lib/commanded/middleware/logging_middleware.ex:102-105` — the correct `Logger` pattern to match

</canonical_refs>

<code_context>

## Existing Code Insights

### Reusable Assets

- `lib/commanded/middleware/logging_middleware.ex:102-105` — already implements the
  `Logger.debug/info/warning/error` dispatch the QUAL-02 fixes should conform to. Reuse this shape
  rather than inventing another.
- `lib/commanded/transformers/generate_aggregate_module.ex:541,636` — already uses
  `require Logger` + `Logger.warning` / `Logger.error` **inside generated AST**. Precedent exists for
  logging in generated code.
- Three `use Ash.Domain` modules already exist in `test/` (`event_handlers_dsl_test.exs:7`,
  `commanded_application_integration_test.exs:7`, `router_transformer_integration_test.exs:19`) —
  useful starting shapes for the `test/support` domain, though none currently has a data layer.
- `config/config.exs` already carries a full `config :ash` block and the Spark formatter section
  ordering — the test data-layer config extends this rather than starting fresh.

### Established Patterns

- Test resources are declared as inline `defmodule` blocks with `domain: nil` (11 files). D-13 keeps
  this for DSL-shape tests and breaks from it only for action-execution tests.
- `BaseTransformer.create_module/3` is the single chokepoint through which all four guarded
  transformers create modules — the guards wrap calls to it, so D-06's deletion is mechanically
  uniform across all four sites.
- Nine verifiers exist in `lib/commanded/verifiers/`. Three more (`ValidateCommandActions`,
  `ValidateCommandHandlers`, `ValidateCommandNameConflict`) are documented in `CLAUDE.md` but **do
  not exist**. Reconciling that is QUAL-06 in Phase 2, not this phase — but TEST-02's rejection-test
  work will touch the nine that do exist.

### Integration Points

- `mix.exs` is touched by six of the ten requirements (QUAL-01, REPO-03, REPO-04, plus the
  `elixirc_paths`, `setup` and `check` aliases). Expect it to be the highest-contention file in the
  phase.
- `.github/workflows/` does not exist — CI is entirely greenfield, no existing pipeline to preserve.
- `test/test_helper.exs` is the single point controlling which tests run; D-15 and D-16 both land
  here.
- Generated AST embeds `use Commanded.Event.Handler` and `use Commanded.Commands.Router`, so the
  D-01 dependency decision and the D-06/D-07 guard removals are mutually dependent — neither works
  without the other. Sequence accordingly.

</code_context>

<specifics>

## Specific Ideas

- **"A test that cannot fail is worse than no test."** The governing principle behind D-06, D-07,
  D-16 and D-17: every mechanism that lets a test not run, or run against a fake, is removed rather
  than reconfigured. Where a masking mechanism is removed, it is not replaced with a different one.
- **`core` parity where it costs nothing.** `mix check` (D-23) and the 1.18/OTP 27 primary CI cell
  (D-20) deliberately mirror `work/core`, so an agent moving between the two repos meets the same
  commands. Credo strictness is the deliberate exception (D-21) — `core` runs `-a --strict`, this
  repo does not, because of the two oversized modules Phases 4 and 6 will decompose.
- **Coverage is reported, not gated** (D-18). The user explicitly accepted that the number may fall
  during triage, and that a falling number measured honestly beats a stable number measured against
  tests that cannot fail. This is a knowing, scoped departure from the standing 80% rule.
- **DSL comprehensibility is a stated project concern.** Raised during this discussion: the original
  library's DSL definitions were not comprehensible, and the user wants that not to repeat. Phase 1's
  share is D-04 (pull Spark's and Ash's own usage rules into the repo). The rest is a roadmap change
  — see Deferred.

</specifics>

<deferred>

## Deferred Ideas

- **In-repo DSL authoring rules → Phase 2 (requires a ROADMAP.md edit).** A new requirement covering
  hard in-repo rules for authoring and maintaining the Spark DSL: section/entity structure,
  "prefer verifiers over transformers for validation", the `ModuleName.Info` introspection
  convention, and the `{:spark_behaviour, _}` / `{:spark_function_behaviour, _, _}` escape-hatch
  types in place of hand-rolled `is_function`/`is_atom` branching. Phase 2 is the right home because
  it is already fixing transformer order and the Domain/Resource boundary — the two things such
  rules must codify. **This has not been applied to ROADMAP.md or REQUIREMENTS.md; it needs an
  explicit roadmap update.**

- **Consumer-facing `usage-rules.md` and `AGENTS.md` → Phase 7 (unchanged).** REPO-01 and REPO-02
  stay where they are. The split agreed: Phase 1 *consumes* upstream rules, Phase 7 *produces* this
  library's own.

- **An `:integration` tag convention → Phase 5.** D-16 removes every default exclusion from
  `test_helper.exs`. Phase 5's PROJ-03 requires a Postgres integration test, which will need some
  way to be excluded from the default run. That convention now has to be introduced deliberately
  rather than inherited.

- **`mix.exs` `files:` list omits `documentation/` and `cheatsheets/` → Phase 7.** The package
  currently ships `~w(lib mix.exs README.md LICENSE .formatter.exs)`, but `docs/0` references 13
  files under `documentation/` and one under `cheatsheets/`. The published package's docs are
  therefore incomplete. Belongs with DOCS-01..04.

- **`spark.cheat_sheets` covers only `AshCommanded.Commanded.Dsl` → Phase 7.** The alias does not
  pass `DomainDsl`. DOCS-04 requires both extensions covered.

- **Bare `rescue` in `snapshot_store.ex` → Phase 4.** D-09 fixes the `IO.puts` only. The rescue
  swallowing all exception classes (including `ArgumentError` from a missing ETS table, a real
  failure mode) is left for the snapshot store rewrite under SNAP-01..03.

- **`Spark.InfoGenerator` adoption and escape-hatch retyping → opportunistic, no dedicated phase.**
  `.planning/research/ARCHITECTURE.md:285` recommends these ride along with whichever phase touches
  each module, but land before the Phase 7 documentation work so the docs describe the final shape.

</deferred>

---

*Phase: 1-Build Integrity*
*Context gathered: 2026-09-12*
