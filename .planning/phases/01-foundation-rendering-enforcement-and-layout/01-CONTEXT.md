# Phase 1: Foundation — Rendering, Enforcement and Layout - Context

**Gathered:** 2026-09-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase builds the instruments, not a component. A developer can see exactly what AshCommanded
generates, and the build rejects generated output that breaks the rewrite rules — so every later
phase has something real to approve against.

It is first because the milestone's per-component method has a fourth step, *"render the generated
output and get human approval"*, which cannot happen until the renderer exists. Research
independently found that **no existing Elixir tool measures macro-emitted code**, so the renderer is
also the precondition for enforcing three of the eleven rewrite rules rather than a convenience.

Covers FOUND-01 through FOUND-18. No component DSL work happens here — commands, events,
application, aggregates and projections all belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Gate staging

- **D-01:** Gates are suppressed on not-yet-rewritten files with per-file
  `# credo:disable-for-this-file` headers, deleted as each component is rewritten. This matches the
  idiom already used in **eight** files (15 disable lines; grep-verified 2026-09-15 — an earlier draft
  of this file said "five files", which was wrong) and keeps the suppression visible at the offence
  rather than in a central allowlist. — **Reversibility:** reversible — the alternative (a central
  allowlist) is a mechanical swap touching only `.credo.exs` and the file headers.
- **D-02:** Every gate disable carries a structured phase reference, and a test parses all disables
  in `lib/` and fails when the cited phase is absent from the current roadmap or already marked
  complete. A disable that outlives its phase becomes a build failure rather than a stale comment.
  This was chosen specifically because the pattern has already decayed once: the 15 disables in
  `lib/` today all cite phase numbers from the archived 13-phase roadmap. Repairing those 15 is a
  side effect of introducing the check, since they all fail until re-pointed.
- **D-03:** Size budgets ratchet. Each golden records its measured sizes; a re-render may shrink or
  hold those numbers but never grow them, so a regression fails even when comfortably under the cap.
  The global caps (clause 10 lines, `quote` 40 lines) sit on top as absolute ceilings. Chosen over
  fixed global numbers because a component that lands at 3 lines would otherwise drift to 9
  unnoticed, and over per-component configured budgets because those become negotiable exactly when
  a gate matters most.
- **D-04:** A budget that must grow is raised by editing the number in the golden's header and
  writing a one-line reason beside it. Because goldens are committed files, the raise appears in the
  PR diff next to the output that caused it. No separate approval mechanism is built.
  Deliberately NOT reusing D-02's phase-annotation mechanism: a Credo disable is temporary and
  should expire with its phase, whereas a legitimate budget raise is permanent.

### Renderer

- **D-05:** `mix ash_commanded.dump <DslModule>` takes a resource or domain and renders every module
  that DSL generated; `--only <GeneratedModule>` narrows to one. Chosen over pointing at a generated
  module directly (what `scripts/render_generated.exs` does today) because the real review loop is
  "I changed the command transformer — show me what a resource generates now".
- **D-06:** The pre-`Module.create/3` AST is captured by the shared codegen helper that FOUND-18
  already requires for explicit `file:`/`line:` metadata. Capture is gated by a flag and the dump
  task forces a recompile of the target with it enabled, so a normal build pays nothing.
  Rejected alternative: embedding a `__ash_commanded_source__/0` in every generated module. It would
  make dumping instant, but the extra function then appears in the post-compile `:beam_lib` view and
  pollutes the very output being reviewed. — **Reversibility:** costly — every transformer must route
  through the helper, so changing the capture mechanism later touches all of them.
- **D-07:** Bare invocation diffs against the committed golden when one exists, and prints the full
  render when one does not. `--write` updates the golden. Zero-flag behaviour matches the common
  case in both situations, rather than requiring `--diff` several hundred times this milestone.
- **D-08:** The renderer ships in the published package and is documented as a real feature, not
  dev-only tooling. A library whose pitch is "we generate the boilerplate you would otherwise
  hand-write" should let consumers see what it generated — that is an answer to the standard
  objection to codegen. It also means `core` can use it during the migration milestone.
  — **Reversibility:** one-way — once published and documented it is a public surface with a
  compatibility expectation; withdrawing it later is a breaking change for anyone depending on it.

### Golden renders

- **D-09:** Goldens are generated from a grown `test/support/parity/`. That tree is already
  deliberately dependency-free with no data layer — *"this resource exists to be compiled, not
  written to"* — which is exactly right for rendering, where fixtures are only ever compiled.
  Growing it also extends the mechanism that turned the dev compiler into a reviewer of generated
  code and found the dead `perform_action/2` clauses. Consequence to plan for:
  `scripts/compile_parity.sh` checks an explicit module list, which must grow alongside the fixtures,
  and every dev compile builds them all.
- **D-10:** One golden file per generated module, foldered per fixture:
  `test/golden/<fixture>/<generated_module>.golden`. Each file carries its own budget line, which
  D-03's ratchet requires, and a change touching only the aggregate produces a diff showing only the
  aggregate.
- **D-11:** `--write` accepts freely when a render improved or held, and **refuses** when a budget
  would grow, directing the developer to edit the budget line and state a reason first (D-04).
  This exists because golden files have one classic failure mode — `--write` becoming reflex, after
  which the golden records what happened rather than what was approved, while every CI check stays
  green. Friction is placed only where judgement is actually needed.
- **D-12:** Golden text diffing runs on one declared canonical Elixir version; the other CI matrix
  legs run the full suite and the size gates but skip the text comparison. The gates still hold
  everywhere because they count sizes rather than compare text. This resolves a direct collision
  between FOUND-04 (goldens diffed in CI) and FOUND-16 (three-version matrix): the render comes from
  `Macro.to_string/1` + `Code.format_string!/1`, both formatter- and version-sensitive, so a golden
  generated on one minor can legitimately differ on another with no change to our generator at all.
  The canonical version must be stated in AGENTS.md so nobody regenerates on the wrong one.

### Namespace and layout

- **D-13:** Flatten to `AshCommanded.Resource.Dsl` and `AshCommanded.Domain.Dsl`, living under
  `lib/ash_commanded/` with sibling `resource/` and `domain/` trees, each holding its own
  `transformers/`, `verifiers/` and `info.ex`. This drops the redundant middle segment in
  `AshCommanded.Commanded.Dsl`, makes the directory match the namespace (today
  `AshCommanded.Commanded.Dsl` lives at `lib/commanded/dsl.ex`), and encodes the resource/domain
  boundary in the directory structure as every mature sibling extension does.
  — **Reversibility:** one-way — this is a published DSL surface. Consumers write
  `extensions: [AshCommanded.Resource.Dsl]`. Licensed by PROJECT.md's decision to break freely on
  0.x while 0.2.0 adoption is negligible; after 1.0 it would need a deprecation cycle.
- **D-14:** The move is big-bang in Phase 1 — every file relocates and renames at once, as a pure
  relocation with no behaviour change, verified by the suite staying green. Accepted cost: roughly
  ten generator files are relocated and then deleted within five phases. Accepted deliberately in
  exchange for never working in a half-migrated tree.
- **D-15:** The DSL block stays `commanded do ... end`. The section names what is being integrated,
  which is what a DSL block should do — as `postgres do` and `graphql do` do in sibling extensions.
  "Commanded" was redundant beside `AshCommanded` in a module path; in the block it is the point.

### Claude's Discretion

- Prefer configuring Credo's existing checks over writing custom ones wherever a built-in covers the
  rule. Stated during discussion and not objected to. Concretely:
  `Credo.Check.Refactor.LongQuoteBlocks` already exists, **is enabled** (`.credo.exs:128`, inside the
  `enabled:` block opened at :68) with defaults, and is currently hand-disabled on
  `generate_aggregate_module.ex` — FOUND-07 may need only `max_line_count: 40` and the deletion of a
  disable. Custom checks only for rules with no built-in: the runtime-reassembly class, string→AST
  reparse, and module-name surgery. `.credo.exs` has empty `plugins: []` and `requires: []` keys
  waiting at lines 39 and 44.

  **Correction (2026-09-15, after phase research).** An earlier version of this file stated that
  `Credo.Check.Design.DuplicatedCode` was "already enabled at `.credo.exs:177`". That is **wrong**.
  Line 177 sits inside the `disabled:` block opened at `.credo.exs:166` — the check is DISABLED. The
  original scout read the line's `[]` options and inferred enablement without checking which block
  contained it. Consequence for FOUND-11: there is nothing to turn off, so adopting `ex_dna` is a
  pure addition rather than a swap.
- The shape and prescriptiveness of AGENTS.md, how `usage_rules` output is generated and kept
  current, and the exact Elixir/OTP versions in the CI matrix were all offered and not selected for
  discussion. Planner has latitude, subject to D-12 requiring the canonical render version be
  recorded in AGENTS.md.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing
- `.planning/PROJECT.md` — Constraints → Rewrite rules holds all eleven gates this phase enforces.
  The `Falsified` section records claims disproved by execution; do not plan against them.
- `.planning/REQUIREMENTS.md` — FOUND-01..18 are this phase's scope, with the method's six steps
  stated at the top.
- `.planning/ROADMAP.md` §Phase 1 — five success criteria, including the five deliberately-seeded
  violations that must fail `mix check` and then go green when removed.
- `.planning/LEARNINGS.md` — §2 assets surviving the rewrite, §5 the eleven rules and where they came
  from, §6 the cross-environment visibility mechanism this phase builds on, §8 open items.
  Note its phase-numbering warning: unqualified "Phase N" there means the archived roadmap.

### Research
- `.planning/research/SUMMARY.md` — read first. Carries the compile-order resolution and its probe
  output, and flags that no tool measures macro-emitted code.
- `.planning/research/STACK.md` — per-rule build-vs-adopt verdicts, `ex_dna` for structural clone
  detection, Credo custom-check mechanics (`Credo.Code.prewalk/2`, `Credo.Test.Case`, the
  `requires:` glob), and the reasoning against `mneme`/`assert_value` for goldens.
- `.planning/research/FEATURES.md` — Spark 2.7.2 API reference. Includes `Spark.InfoGenerator`, which
  this phase uses to establish the `.Info` convention.
- `.planning/research/ARCHITECTURE.md` §7 — the recommended `lib/` layout D-13 adapts.
- `.planning/research/PITFALLS.md` — P15 (spurious warnings, bad stacktraces), P16 (`Module.create/3`
  losing caller env) and P17 (compile-time dependency cascades) are assigned to this phase.
  Its "Looks Done But Isn't" checklist applies directly to FOUND-06..11.

### Existing assets this phase builds on
- `scripts/render_generated.exs` — working prototype of the post-compile `:beam_lib` path (FOUND-03).
  Renders `debug_info` via `Macro.to_string/1` + `Code.format_string!/1`. Note it is
  post-macro-expansion, so `use X` appears as the functions it injected.
- `scripts/compile_parity.sh` — cross-environment check; its explicit module list grows with D-09.
- `test/support/parity/` — the fixture tree D-09 grows. On the `:dev` elixirc path by design.
- `.credo.exs` — 221 lines; `plugins: []` at :39, `requires: []` at :44, `LongQuoteBlocks` at :128,
  `DuplicatedCode` at :177.
- `mix.exs` — the `check` alias (:dev by default, with `test` spawned in its own MIX_ENV subprocess
  and a comment explaining why); `usage_rules ~> 1.2` is already a dev dependency at :67.
- **`.github/workflows/` does not exist.** FOUND-16 and D-12 author CI from scratch rather than
  adjusting an existing matrix. LEARNINGS.md §2 lists it conditionally ("if plan 01-08 lands before
  the rewrite begins"); plan 01-08 never ran, so the condition did not hold.
- `.planning/evidence-generated-aggregate.txt` — the 333-line pre-rewrite aggregate render. The
  before-picture later phases measure against.

### Stale — do not trust
- `.planning/codebase/*.md` — mapped 2026-09-11, before the archived phase rewrote the toolchain.
  Stale on exactly the areas this phase touches. Re-read the live tree instead.
- `CLAUDE.md` — documents three verifiers that do not exist and three stale dependency versions.
  Reconciled in Phase 7; treat every factual claim as unverified until then.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/render_generated.exs`: a working `:beam_lib` renderer, already handling the formatter
  rejecting imperfectly-round-tripping AST by falling back to unformatted output. FOUND-03's
  post-compile path is largely this, promoted into a mix task.
  **Do not overestimate its coverage.** It covers ONLY the `--beam` flag path. The DEFAULT bare
  invocation (FOUND-01/02/05, pre-`Module.create/3` AST) has no prototype in this repo at all and
  depends entirely on the new D-06 capture hook. The prototype is a fallback view, not a head start
  on the primary one.
- `test/support/parity/` + `scripts/compile_parity.sh`: the fixture and checking mechanism D-09
  extends rather than replaces.
- `.credo.exs`'s empty `plugins: []` and `requires: []`: the hooks for `ex_dna` and for in-repo
  custom checks already exist and are unused.
- `mix.exs`'s `check` alias: the gate list this phase extends. Its existing comment explains the
  :dev/:test split — Dialyzer has no `:ex_unit` in its PLT, so analysing `test/support` under
  MIX_ENV=test raises spurious findings. Preserve that reasoning when adding steps.
- `usage_rules ~> 1.2` at `mix.exs:67`: already present, so FOUND-13 is partly done.

### Established Patterns
- `# credo:disable-for-this-file` headers at the top of offending files — D-01 extends this rather
  than introducing a second suppression convention.
- `lib/commanded/transformers/base_transformer.ex` exists and has a `create_module/3` that
  transformers already route through; FOUND-18's helper and D-06's capture hook are likely an
  evolution of it rather than a new module.
- Generated module names follow `<ResourceModule>.Commands.<CommandName>` and siblings.

### Known Collision — FOUND-10 vs FOUND-18

`Module.split`/`Module.concat` appear **30 times across 13 files** in `lib/` (verified 2026-09-15),
not the single site LEARNINGS.md cites. Three of them are `lib/commanded/transformers/base_transformer.ex`
lines 22, 26 and 41 — inside `get_module_prefix/1`, which is the very seam FOUND-18's shared codegen
helper and D-06's capture hook attach to. **A FOUND-10 check that flags module-name surgery will fire
on the module this phase is building.** The planner must decide explicitly: rewrite
`get_module_prefix/1` to derive from `Transformer.get_persisted/2`, or suppress it under D-01/D-02's
phase-annotated disable — and if suppressed, name the phase that removes it.

Not every occurrence is the defect. The check needs to separate three uses that look alike:
deriving a module atom to reference (the real defect — `generate_command_modules.ex:99` and
siblings); building a display string (`logging_middleware.ex:37,57,75` take `List.last()` for a log
label); and naming a process (`generate_commanded_application.ex:130,135` name a Supervisor).
Pattern mapping found a fourth, borderline case at `generate_commanded_application.ex:231-248`, which
derives a module name from a domain name *and* is real surgery — decide it explicitly rather than
letting the taxonomy decide it by accident. False-positive design is therefore part of FOUND-10, not
an afterthought.

### Integration Points
- Every transformer must route module creation through the shared helper for D-06's capture to be
  complete — a transformer that calls `Module.create/3` directly renders as a hole in the output.
  Research confirmed `base_transformer.ex:70-74`'s `create_module/3` is already called by all nine
  module-creating transformers, so the seam exists and is singular.
- `compile_parity.sh`'s explicit module list and `mix.exs`'s `check` alias both need extending, and
  CI invokes the alias rather than restating steps, so the two cannot drift.
- The D-13 rename touches every file in `lib/` and `test/`, plus the `spark.cheat_sheets` alias,
  which currently names `AshCommanded.Commanded.Dsl` explicitly.

</code_context>

<specifics>
## Specific Ideas

- The renderer's diff output should print the budget deltas alongside the source diff
  (`clause_max 14 -> 3   module_lines 333 -> 41`), so an improvement is legible without counting.
- `--write`'s refusal message should name the budget that would grow, the old and new values, and
  the exact file and line to edit — a refusal that does not say what to do next is a dead end.
- The `.golden` header format carries the budget inline as a comment
  (`# gsd-budget: clause_max=6 module_lines=48`) so the number travels with the artefact it
  describes and moves in the same diff.

</specifics>

<deferred>
## Deferred Ideas

- **Postgres-backed EventStore example** — already recorded in REQUIREMENTS.md as deferred to the
  migration milestone, since it proves the path that migration uses.
- **Reverting `workflow.use_worktrees: false`** — repository housekeeping once this branch merges.
  Already in ROADMAP.md's Out of Roadmap Scope and STATE.md blockers.
- **AGENTS.md shape, `usage_rules` generation workflow, exact CI matrix versions** — offered as gray
  areas and not selected. Not deferred out of the phase; planner has latitude within FOUND-14/15/16.

</deferred>

---

*Phase: 1-Foundation — Rendering, Enforcement and Layout*
*Context gathered: 2026-09-15*
