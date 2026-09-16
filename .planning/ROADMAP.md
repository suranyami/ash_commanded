# Roadmap: AshCommanded — Milestone v0.3 Library Rewrite

## Overview

The generation layer is rewritten component by component, in place, with the 176-test suite and
`mix check` green at every commit. Foundation comes first and is not negotiable: no Elixir tool
measures macro-emitted code, so until `mix ash_commanded.dump` and a golden-render harness exist,
the per-component method's fourth step — *render the generated output and get human approval* —
cannot happen at all, and three of the eleven rewrite rules have nothing to enforce them. With the
renderer in hand the components land cheapest-first, deliberately: commands and events prove the
render-and-approve loop on struct generation where the answer is obvious, then application and
routers (planned as one unit, because the confirmed defect spans both and neither can be
demonstrated working alone), then aggregates — the component whose 861-line generator caused this
rewrite — then projections with the handlers and process managers they must be distinguishable
from. The last two phases cover what a long-lived event-sourced system needs beyond the happy path
(schema evolution, snapshots, middleware, transactions) and the documentation, packaging and
runnable example that make the library adoptable. `core`'s migration and the 1.0 publish are
deliberately absent: both belong to the next milestone, planned against a DSL that by then exists.

**Phase numbering restarts at 1.** The previous 13-phase roadmap was discarded, not completed, and
is archived at `.planning/milestones/archived-20260915-phases/`.

**Granularity note.** `config.json` sets `standard` (4-6 phases); this roadmap has 7. The excess is
structural, not padding: Foundation is a hard precondition, the six-step method is per-component so
components cannot be dissolved into each other freely, and the user's fixed component order
(commands → events → application → aggregates → projections) constrains grouping. Three
compressions were applied against the natural ten-category split — commands with events,
projections with handlers and process managers, event versioning with the runtime surfaces.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation — Rendering, Enforcement and Layout** - The renderer, golden files and executable rewrite-rule gates that every later phase's approval step depends on
- [ ] **Phase 2: Commands and Events** - The cheapest components, where the render-and-approve method is proven before it meets a hard one
- [ ] **Phase 3: Application and Routers** - One coupled unit: the confirmed router-generation defect fixed, and a command dispatched end to end
- [ ] **Phase 4: Aggregates** - A hand-written `__using__` front door and runtime module, with generated clauses carrying only literals
- [ ] **Phase 5: Projections, Event Handlers and Process Managers** - Three distinct generated shapes, judged side by side rather than collapsed into one base
- [ ] **Phase 6: Event Versioning, Snapshots, Middleware and Transactions** - What a long-lived event-sourced system needs beyond the happy path, targeting Commanded's real internals
- [ ] **Phase 7: Documentation, Packaging and the End-to-End Example** - A runnable example, a testing story, and documentation with no claim the code does not support

## Phase Details

### Phase 1: Foundation — Rendering, Enforcement and Layout

**Goal**: A developer can see exactly what AshCommanded generates, and the build rejects generated
output that breaks the rewrite rules — so every later phase has something real to approve against.
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10, FOUND-11, FOUND-12, FOUND-13, FOUND-14, FOUND-15, FOUND-16, FOUND-17, FOUND-18
**Success Criteria** (what must be TRUE):

  1. `mix ash_commanded.dump <Module>` prints formatted, readable Elixir source for every module the DSL generated for that module. By default it prints the AST as the transformer wrote it, with `use X` still `use X`; with the BEAM flag it prints the post-compile `debug_info` view, and a developer can see the two differ where macros expanded.
  2. Golden renders are committed as ordinary files, and CI fails with a readable per-line diff when a generator's output changes. A developer regenerates them with one documented command, and `git diff` after that command shows exactly the change they made.
  3. Five deliberately-seeded violations each fail `mix check` with a message naming the file and rule: a rendered clause over ~10 lines, a `quote` block over 40 lines, compile-time-known values reassembled at runtime (the `:erlang.++` defect), `Code.string_to_quoted!`/`eval_string` in a transformer, and a module name built by `Module.split`/`Module.concat` surgery. Removing each seeded violation turns the build green again.
  4. A developer runs the structural clone check across `lib/` and reads a report naming clone pairs that Credo's built-in duplicate check does not report; `AGENTS.md` carries Rule 9 ("no double-handling") as a reviewer checklist item with an explicit statement that no mechanical check for it exists.
  5. `AGENTS.md` exists documenting idiomatic Elixir, DSL conventions, transformer ordering, testing expectations and the Spark API surface, with `core` as the worked reference; `usage_rules` is a dev dependency and the library's generated usage rules are committed; `lib/` has sibling `resource/` and `domain/` trees each holding `transformers/`, `verifiers/` and `info.ex`; a deliberate error in generated code reports a `file:`/`line:` a developer can open; and CI runs the suite green on the current Elixir/OTP release plus the previous two minors.

**Plans:** 6/6 plans executed

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Tracer: AST capture seam, `mix ash_commanded.dump`, one golden, the clause-size gate, and explicit file/line metadata (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Renderer expansion: `--beam`, `--write` ratchet, canonical-version golden diff, runtime-reassembly lint, full golden corpus (wave 2)
- [x] 01-03-PLAN.md — Static gates: two custom Credo checks, quote-block ceiling, structural clone detection and the clone report (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-04-PLAN.md — The big-bang namespace move: `resource/` and `domain/` trees, `.Info` modules, and the golden-diff neutrality proof (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-05-PLAN.md — Seeded-violation fixtures, the gate meta-test, phase-cited suppressions and the gate-evidence record (wave 4)
- [x] 01-06-PLAN.md — `usage-rules.md`, `AGENTS.md` and the first CI workflow with a three-leg matrix (wave 4)

### Phase 2: Commands and Events

**Goal**: A developer declares commands and events on an `Ash.Resource` and gets struct modules
whose rendered output a human has read and approved, with every misuse rejected at compile time.
**Depends on**: Phase 1
**Requirements**: CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, CMD-06, CMD-07, CMD-08, CMD-09, EVT-01, EVT-02, EVT-03, EVT-04, EVT-05, EVT-06
**Success Criteria** (what must be TRUE):

  1. A resource declaring a command with fields, a named Ash action, an overridden module name and a nominated identity field compiles, and in `iex` the generated struct exists with those fields and a `@type t`. The same holds for an event declared with fields and an overridden module name.
  2. Five seeded misuses each fail `mix compile` with a message naming the offending element: duplicate command name, duplicate event name, a command field that is not a resource attribute, an event field that is not a resource attribute, and a command action that does not exist on the resource.
  3. `AshCommanded.Resource.Info` returns a resource's declared commands and events, and `grep` across `lib/` and `test/` finds no other code reading that information out of DSL state directly.
  4. A human has run `mix ash_commanded.dump` on a generated command module and a generated event module, read the output, and recorded approval against the size gates in the phase's verification record. Golden files for both are committed and the CI diff is green.
  5. `mix check` is green and the suite is at or above 176 tests with 0 failures, with the old command and event generators and their tests deleted rather than left alongside.

**Sequencing note**: Commands land and are approved before event work begins — commands are the
first exercise of the render-and-approve loop and the point at which the method itself is judged.
Events follow because they are the same shape, which is why the two share a phase.

**Plans**: TBD

### Phase 3: Application and Routers

**Goal**: A domain that declares commands produces a Commanded application and a router that both
actually generate, and a developer can dispatch a command through them and watch an aggregate act
on it.
**Depends on**: Phase 2
**Requirements**: APP-01, APP-02, APP-03, APP-04, APP-05, APP-06, APP-07, APP-08, APP-09, APP-10, APP-11, APP-12
**Success Criteria** (what must be TRUE):

  1. A domain declaring an application compiles and `mix ash_commanded.dump <Domain>` shows both the generated application module and its router. The `__registered_commands__/0 is undefined` failure is gone, and the domain transformer reaches each resource's commands via `Ash.Domain.Info.resources/1` and persisted state — the module-name-surgery check from Phase 1 stays green.
  2. A test dispatches a command through the generated router and asserts on the resulting aggregate state, passing in a full `mix test` run rather than only in isolation.
  3. A developer can set event store, pubsub, registry and supervision through the DSL and see the values in the rendered application; projectors appear in the generated supervision tree without being listed by hand, and the auto-discovery TODO is gone from the source.
  4. `commanded_application_integration_test.exs` is restored without the `.phase2-blocked` suffix, exercises real application generation, and `grep -rn "Code.ensure_loaded?" test/` returns nothing.
  5. `AshCommanded.Domain.Info` returns the domain's application configuration; a design note in the repository records that compile ordering comes from an on-demand compiler block in `persisted!/3`, not a declared dependency edge, and that a resource transformer reading back from its domain risks deadlock. The rendered application and router modules have been read and approved by a human against the size gates, with golden files committed.

**Coupling note**: Application and routers are one phase because the confirmed defect spans both —
router generation never fires for any domain, and the application cannot be demonstrated working
without a router to register commands into. This follows REQUIREMENTS.md's APP grouping and the
research recommendation, and supersedes the research document's separate suggestion of grouping
routers with event handlers and process managers.

**Plans**: TBD

### Phase 4: Aggregates

**Goal**: Aggregate machinery lives in hand-written, unit-testable runtime modules behind a
`__using__` front door, generated aggregate clauses carry only per-entity literals, and the DSL can
express the invariants, non-attribute state and lifespan that `core`'s aggregates actually use.
**Depends on**: Phase 3
**Requirements**: AGG-01, AGG-02, AGG-03, AGG-04, AGG-05, AGG-06, AGG-07, AGG-08, AGG-09
**Success Criteria** (what must be TRUE):

  1. `AshCommanded.Aggregate.__using__/1` exists as hand-written source a developer can read straight through, and the aggregate execution logic sits in a plain runtime module exercised by a test file that compiles no DSL and references no Ash resource.
  2. `mix ash_commanded.dump` on a one-command, one-event resource shows an aggregate whose `execute/2` and `apply/2` clauses each fit the ~10-line gate and whose whole module fits the documented budget; a human has read that render and recorded approval, and its golden file is committed. For reference, the pre-rewrite render is preserved at `.planning/evidence-generated-aggregate.txt`.
  3. A developer can declare an invariant that rejects a command based on current aggregate state, declare aggregate state that is not a resource attribute (such as a member collection), and declare `after_event`, `after_command` and `after_error` lifespans — each observable through a dispatch in a passing test.
  4. A command returning no event, one event, a list of events, and an error each behaves per Commanded's documented contract, with a test per case.
  5. `AshCommanded.Aggregate.Info` is the single lookup point for per-command configuration — `grep` finds no other place reconstructing it — and `mix check` is green with the old aggregate generator and its tests deleted.

**Plans**: TBD

### Phase 5: Projections, Event Handlers and Process Managers

**Goal**: Events reach read models and side effects through three visibly distinct generated
shapes, and the two latent defects in this area are fixed by tests that would have caught them.
**Depends on**: Phase 4
**Requirements**: PROJ-01, PROJ-02, PROJ-03, PROJ-04, PROJ-05, PROJ-06, PROJ-07, HDLR-01, HDLR-02, HDLR-03, HDLR-04, HDLR-05, HDLR-06
**Success Criteria** (what must be TRUE):

  1. A developer can declare a projection mapping an event to an Ash action with static changes, and another computing changes from the event via a function; both are observable as a changed Ash record after a real dispatch.
  2. Two seeded misuses each fail `mix compile` naming the offender: a projection referencing an unknown event, and a projection writing an unknown attribute.
  3. The `Ash.run_action(changeset, action)` defect is fixed, and a test that fails against the current code passes against the new. A test asserts on a projected Ash record after a real dispatch, with the `private? true` cross-process ETS limitation either resolved or documented in the test file alongside the assertion that works around it.
  4. A developer can declare an event handler that runs a side effect without touching the resource, declare a process manager coordinating across aggregates, and choose `:strong` or `:eventual` consistency per handler — each with a passing test. A handler that raises surfaces through Commanded's error callback, proven by a test asserting the callback ran.
  5. `mix ash_commanded.dump` shows three distinguishable module shapes for projector, event handler and process manager rather than one generic base; a human has read all three renders and recorded approval against the size gates, and their golden files are committed.

**Grouping note**: These share a phase because HDLR-05 requires handlers, projectors and process
managers to generate *distinct* shapes — a property only judgeable with all three rendered side by
side. Splitting them would defer the one requirement that compares them.

**Plans**: TBD

### Phase 6: Event Versioning, Snapshots, Middleware and Transactions

**Goal**: The realities of a long-lived event-sourced system — schema evolution, snapshots,
middleware and transactions — are declarative and aimed at Commanded's real internals rather than
at surfaces that never existed.
**Depends on**: Phase 5
**Requirements**: EVOL-01, EVOL-02, EVOL-03, EVOL-04, EVOL-05, RUN-01, RUN-02, RUN-03, RUN-04, RUN-05, RUN-06, RUN-07
**Success Criteria** (what must be TRUE):

  1. A developer can declare how a historical event shape maps to the current one across several versions, and `mix ash_commanded.dump` shows exactly one `upcast/2` clause per historical struct, each returning the **current** struct directly with the intermediate steps already composed away — visible in the render, not inferred from the generator. A human has read and approved that render against the size gates.
  2. A replay test writes an event at the oldest declared version into the event store, replays it, and asserts the handler receives the current struct shape.
  3. A developer can declare `snapshot_every` and `snapshot_version` per aggregate and see the resulting `Commanded.Snapshotting` configuration in the rendered application; `grep -rn "Snapshotter" .` returns nothing.
  4. A middleware module that does not implement Commanded's real middleware contract is rejected at compile time by a named verifier, with a message naming the module; two attached middlewares are observed running in declaration order by a test asserting on the order.
  5. A test exercises a real transaction rollback and asserts nothing was persisted, and `grep -rn "IO.puts\|IO.inspect" lib/` returns nothing.

**Plans**: TBD

### Phase 7: Documentation, Packaging and the End-to-End Example

**Goal**: A developer who has never seen AshCommanded can clone it, run a working event-sourced
example, and follow documentation in which no claim outruns the code.
**Depends on**: Phase 6
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06, DOCS-07, DOCS-08
**Success Criteria** (what must be TRUE):

  1. A developer runs one documented command and watches a full command → event → projection → read-model cycle complete on Commanded's in-memory adapter, fast enough to run in CI and in the docs build.
  2. A testing guide shows how to test commands, aggregates, projections and full event flows, and every snippet in it is either executed by the suite or copied verbatim from a passing test — checkable by a reader following the file references.
  3. Every factual claim in `CLAUDE.md` is checkable against the code: the three documented-but-absent verifiers are gone or real, and declared dependency versions match `mix.exs` and `mix.lock`. A reader comparing `CLAUDE.md` with `AGENTS.md` finds them consistent rather than divergent.
  4. `mix spark.cheat_sheets` produces cheatsheets for the domain extension as well as the resource extension, and `mix hex.build` lists `documentation/` and `cheatsheets/` among the packaged files.
  5. `mix deps.get` resolves current dependency versions including a bumped `sourceror`, and `mix check` is green on the bumped set on every Elixir version in the CI matrix.

**Plans**: TBD

## Method

Every component phase (2 through 6) runs the same six-step loop per component, and a component is
not complete until all six are done:

1. Propose the DSL surface
2. Write a runnable usage example
3. Build the transformer(s)
4. **Render the generated output with `mix ash_commanded.dump` and get human approval of its conciseness**
5. Iterate the transformer if the render is unsatisfactory
6. Add persisters/verifiers and a test suite; `mix check` green

Step 4 is why Phase 1 cannot move. It is also why every component phase carries an approval
criterion: a component phase is not done until a human has read its rendered output and said so.

## Standing Constraints

These hold across every phase and are not restated per phase:

- **In place, not in parallel.** Delete the old component and its tests, write fresh against
  `.planning/LEARNINGS.md` rather than against the old code. No parallel namespace.
- **Green at every commit.** 176 tests, 0 failures, and `mix check` all blocking. The real alias is
  `format --check-formatted` → `compile --warnings-as-errors` → `credo` → `test` →
  `scripts/compile_parity.sh` → `dialyzer` → `gen.docs`. **Corrected 2026-09-15:** an earlier version
  of this line said "format + Credo strict + Dialyzer + Sobelow + test". There is no Sobelow step,
  and `credo` runs non-strict by deliberate decision (archived phase D-21), not by omission — do not
  "restore" either. This is the judging bar established in the previous milestone and it does not relax.
- **Assets that survive.** `mix.exs` toolchain, `.credo.exs`, `.dialyzer_ignore.exs`,
  `test/support/` fixtures, `test/support/parity/` + `scripts/compile_parity.sh`, and the suite
  itself. See `.planning/LEARNINGS.md` §2.
- **Settled facts, not to be re-derived.** An ordinary domain transformer can read resource-level
  persisted state directly — no `after_compile?` deferral needed, the ordering comes from an
  on-demand compiler block, and the residual risk is deadlock on a bidirectional read, not missing
  state. `Commanded.Event.Upcaster` upcasts exactly once per event, never chained. Spark
  auto-prepends `VerifyEntityUniqueness` and `VerifySectionSingletonEntities`, so `identifier:` and
  `singleton_entity_keys` replace hand-written uniqueness verifiers. See
  `.planning/research/SUMMARY.md`.

## Out of Roadmap Scope

- `core`'s five-domain migration (MIG-01..05) and the 1.0 hex.pm publish (REL-01) — next milestone.
- A Postgres-backed end-to-end example (EX-01) — belongs with the migration it serves.
- Reverting `workflow.use_worktrees: false` in `.planning/config.json` — repository housekeeping
  after `fix-application-generation` merges, tracked in `.planning/LEARNINGS.md` §8, not a
  milestone requirement.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase                                                       | Plans Complete | Status      | Completed |
| ----------------------------------------------------------- | -------------- | ----------- | --------- |
| 1. Foundation — Rendering, Enforcement and Layout           | 6/6 | In Progress|  |
| 2. Commands and Events                                      | 0/TBD          | Not started | -         |
| 3. Application and Routers                                  | 0/TBD          | Not started | -         |
| 4. Aggregates                                               | 0/TBD          | Not started | -         |
| 5. Projections, Event Handlers and Process Managers         | 0/TBD          | Not started | -         |
| 6. Event Versioning, Snapshots, Middleware and Transactions | 0/TBD          | Not started | -         |
| 7. Documentation, Packaging and the End-to-End Example      | 0/TBD          | Not started | -         |

**Coverage:** 87/87 milestone requirements mapped, each to exactly one phase.

---
*Roadmap created: 2026-09-15 for milestone v0.3 Library Rewrite*
*Supersedes the archived 13-phase roadmap at `.planning/milestones/archived-20260915-phases/`*
