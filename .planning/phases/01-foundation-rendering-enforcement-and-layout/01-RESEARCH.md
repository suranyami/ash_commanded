# Phase 1: Foundation — Rendering, Enforcement and Layout - Research

**Researched:** 2026-09-15
**Domain:** Elixir/Spark DSL code-generation tooling — a render pipeline, size/shape enforcement,
custom static analysis, and a big-bang namespace relocation
**Confidence:** HIGH for everything read directly from source in this session (file:line cited);
MEDIUM for the concrete mechanism designs proposed below (they extend verified primitives but the
mix task/tests themselves do not exist yet, so the *design* is a recommendation, not an observation);
LOW/ASSUMED explicitly flagged where a package name or config key came from web search only.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Gates are suppressed on not-yet-rewritten files with per-file
  `# credo:disable-for-this-file` headers, deleted as each component is rewritten.
- **D-02:** Every gate disable carries a structured phase reference, and a test parses all disables
  in `lib/` and fails when the cited phase is absent from the current roadmap or already marked
  complete. The 15 disables in `lib/` today all cite phase numbers from the archived 13-phase
  roadmap and all fail until re-pointed.
- **D-03:** Size budgets ratchet. Each golden records its measured sizes; a re-render may shrink or
  hold those numbers but never grow them. Global caps (clause 10 lines, `quote` 40 lines) sit on top
  as absolute ceilings.
- **D-04:** A budget that must grow is raised by editing the number in the golden's header and
  writing a one-line reason beside it. No separate approval mechanism is built.
- **D-05:** `mix ash_commanded.dump <DslModule>` takes a resource or domain and renders every module
  that DSL generated; `--only <GeneratedModule>` narrows to one.
- **D-06:** The pre-`Module.create/3` AST is captured by the shared codegen helper that FOUND-18
  already requires for explicit `file:`/`line:` metadata. Capture is gated by a flag and the dump
  task forces a recompile of the target with it enabled, so a normal build pays nothing. Rejected
  alternative: embedding `__ash_commanded_source__/0` in every generated module (pollutes the output
  under review). Reversibility: costly — every transformer must route through the helper.
- **D-07:** Bare invocation diffs against the committed golden when one exists, prints the full
  render when one does not. `--write` updates the golden.
- **D-08:** The renderer ships in the published package and is documented as a real feature, not
  dev-only tooling. Reversibility: one-way (public surface once published).
- **D-09:** Goldens are generated from a grown `test/support/parity/`. `scripts/compile_parity.sh`
  checks an explicit module list, which must grow alongside the fixtures.
- **D-10:** One golden file per generated module, foldered per fixture:
  `test/golden/<fixture>/<generated_module>.golden`. Each file carries its own budget line.
- **D-11:** `--write` accepts freely when a render improved or held, and **refuses** when a budget
  would grow, directing the developer to edit the budget line and state a reason first (D-04).
- **D-12:** Golden text diffing runs on one declared canonical Elixir version; other CI matrix legs
  run the full suite and size gates but skip the text comparison, because the render comes from
  `Macro.to_string/1` + `Code.format_string!/1`, both formatter- and version-sensitive. The canonical
  version must be stated in AGENTS.md.
- **D-13:** Flatten to `AshCommanded.Resource.Dsl` and `AshCommanded.Domain.Dsl`, living under
  `lib/ash_commanded/` with sibling `resource/` and `domain/` trees, each holding its own
  `transformers/`, `verifiers/` and `info.ex`. Reversibility: one-way — published DSL surface.
- **D-14:** The move is big-bang in Phase 1 — every file relocates and renames at once, as a pure
  relocation with no behaviour change, verified by the suite staying green.
- **D-15:** The DSL block stays `commanded do ... end` even though the module namespace drops
  "Commanded." "Commanded" was redundant beside `AshCommanded` in a module path; in the block it is
  the point.

### Claude's Discretion

- Prefer configuring Credo's existing checks over writing custom ones wherever a built-in covers the
  rule. `Credo.Check.Refactor.LongQuoteBlocks` already exists, enabled at `.credo.exs:128` with
  defaults, hand-disabled on `generate_aggregate_module.ex` — FOUND-07 may need only
  `max_line_count: 40` and the deletion of that disable (**see Correction #1 below regarding the
  `Credo.Check.Design.DuplicatedCode` half of this claim — it is verified wrong**).
  `.credo.exs` has empty `plugins: []` and `requires: []` waiting at lines 39 and 44. Custom checks
  only for rules with no built-in: the runtime-reassembly class, string→AST reparse, and
  module-name surgery.
- The shape and prescriptiveness of AGENTS.md, how `usage_rules` output is generated and kept
  current, and the exact Elixir/OTP versions in the CI matrix were offered and not selected for
  discussion. Planner has latitude, subject to D-12 requiring the canonical render version be
  recorded in AGENTS.md.

### Deferred Ideas (OUT OF SCOPE)

- Postgres-backed EventStore example — deferred to the migration milestone.
- Reverting `workflow.use_worktrees: false` — repository housekeeping once this branch merges.
- AGENTS.md shape, `usage_rules` generation workflow, exact CI matrix versions — offered as gray
  areas and not selected; not deferred out of the phase, planner has latitude.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
| ---- | ------------- | ------------------ |
| FOUND-01 | `mix ash_commanded.dump <Module>` renders generated code | Open Q1 — concrete mix-task mechanism |
| FOUND-02 | Default: pre-`Module.create/3` AST | Open Q1 — capture is exactly this view |
| FOUND-03 | Post-compile `debug_info` behind a flag | Open Q1 — promote `scripts/render_generated.exs` |
| FOUND-04 | Golden renders committed, diffed in CI | Open Q2 — ratchet mechanics; CI Matrix section |
| FOUND-05 | Single documented regen command | Open Q1 — `--write` |
| FOUND-06 | Clause >10 lines fails build | Open Q2 — size-budget test design |
| FOUND-07 | `quote` block >40 lines fails build | Correction #1 + Q6 — Credo `LongQuoteBlocks`, D-01 sequencing |
| FOUND-08 | Compile-time values reassembled at runtime fails build | Open Q3 — rendered-output check, not Credo-on-lib |
| FOUND-09 | `Code.string_to_quoted!`/`eval_string` in transformer fails build | Open Q3 — Credo check on `lib/` |
| FOUND-10 | Module-name surgery fails build | Open Q3 + Verified Fact #2 (multi-site defect) |
| FOUND-11 | Structural duplicate detection beyond Credo's built-in | Open Q6 — `ex_dna` integration, `[ASSUMED]` package |
| FOUND-12 | Rule 9 ("no double-handling") reviewer checklist | Don't Hand-Roll section; STACK.md Rule 5 (no tool exists) |
| FOUND-13 | `usage_rules` dev dep + published usage rules | Open Q7 |
| FOUND-14 | AGENTS.md: idiomatic Elixir, DSL conventions, ordering, testing | Open Q7; Architecture Patterns |
| FOUND-15 | AGENTS.md: Spark API reference | Open Q7; defers to FEATURES.md |
| FOUND-16 | CI matrix, current + 2 minors | CI Matrix section — Verified Fact #3 (no `.github/` exists yet) |
| FOUND-17 | `lib/` reorganised into resource/domain trees | Open Q5 — big-bang move mechanics |
| FOUND-18 | Shared module-creation helper with `file:`/`line:` | Open Q1 — `BaseTransformer.create_module/3` is the seam |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

Root `~/.claude/CLAUDE.md` and `~/.claude/rules/` mandate (apply as authority equal to locked
decisions, verified against this repo where relevant):

- **GSD workflow enforcement** (`.claude/CLAUDE.md` at repo root): file-changing tools must go
  through a GSD command; this research feeds `/gsd-plan-phase`, so no direct action needed here.
- **80% test coverage minimum, TDD workflow** (`rules/common/testing.md`) — the phase's own
  size-budget/Credo/seeded-violation tests must themselves be test-first per this rule; the planner
  should sequence "write the meta-test asserting the check fires" before "write the check."
- **Immutability, small files (200–400 typical/800 max), explicit error handling**
  (`rules/common/coding-style.md`) — directly relevant to the D-13 relocation: this is the opening
  the rewrite has to also break up any file approaching the 800-line ceiling while it's already being
  moved (e.g. `command_action_mapper.ex` at 639 lines, `error.ex` at 514 — both under the ceiling
  today, flag only if the move touches them further).
- **No hardcoded secrets, mandatory security checks before commit** (`rules/common/security.md`) —
  no secrets are introduced by this phase; see Security Domain section below for the narrower
  supply-chain framing that actually applies (new dev dependency `ex_dna`).
- **Git workflow**: conventional commit types, no attribution footer (disabled globally). This
  project's own `.planning` commit convention (`docs(NN): ...`) should be followed for phase docs,
  ordinary `feat`/`fix`/`refactor`/`chore` for code changes, matching the repo's actual recent commits
  (`chore: ignore editor-local...`, `docs(01): capture phase context`).
- **Code review before commit** (`rules/common/code-review.md`) — the project's own `.claude/CLAUDE.md`
  security/code-review directives are additive to, not a replacement for, this repo's own `mix check`
  gate; both apply.

None of these conflict with any locked decision above; no contradiction to flag.

## Corrections to Prior Research (verified this session)

These correct or sharpen claims made in CONTEXT.md/STACK.md/PROJECT.md against the actual file
contents, read directly in this session.

### Correction #1 — `Credo.Check.Design.DuplicatedCode` is NOT currently enabled

CONTEXT.md's Claude's Discretion section states it is "likewise already enabled at `.credo.exs:177`."
**This is wrong.** `[VERIFIED: .credo.exs:166,177 — read this session]`:

```elixir
166         disabled: [
...
177           {Credo.Check.Design.DuplicatedCode, []},
```

Line 177 is correct; it sits inside the `disabled:` list (opened at line 166), not `enabled:`. It is
**already off**. The practical consequence for FOUND-11: there is **nothing to disable** — the task
is only to *add* `ex_dna`'s replacement check to `plugins:`/`checks: enabled:`. The companion claim
about `Credo.Check.Refactor.LongQuoteBlocks` ("already exists, enabled at `.credo.exs:128` with
defaults") **is correct** — `[VERIFIED: .credo.exs:128]`, it sits inside `enabled:` (opened line 68).

### Correction #2 — the module-name-surgery defect is not a single line, it recurs at ≥6 sites

LEARNINGS.md/PITFALLS.md cite one instance (`generate_aggregate_module.ex:235`, now at line 244-247
after intervening edits). Reading every transformer directly this session
`[VERIFIED: lib/commanded/transformers/*.ex, lib/commanded/transaction.ex — grep + read, this session]`
finds the `Module.split()` → (`Enum.drop`/`List.last`) → `Module.concat()` pattern at:

| File:line | Shape | Verdict |
| --- | --- | --- |
| `base_transformer.ex:22,26` (`get_module_prefix/1`) | split, drop last segment, re-concat | **The shared utility itself does this** — many legitimate call sites use it correctly (compute a *new* namespace prefix, not reconstruct an existing reference) |
| `generate_aggregate_module.ex:244-247` | split command module, drop 2, append resource_name, re-concat | **The confirmed defect** — reconstructs the resource module from the command module's name when the resource module is already available via `get_persisted/2` earlier in the same file (comment at lines 238-241 shows the author was aware and left it anyway) |
| `generate_commanded_application.ex:231` | `domain_module \|> Module.split() \|> List.last()` | Milder — extracts only a short name, not a full reconstruction |
| `generate_projector_modules.ex:98` | same `Module.split() \|> List.last()` pattern | Milder, same as above |
| `generate_main_router_module.ex:190` | same pattern | Milder, same as above |
| `transaction.ex:169` | `Module.split()` (concat side not confirmed in this pass) | Needs its own read before Phase 1 closes |

**Consequence for the FOUND-10 Credo check:** a naive "flag any `Module.split` whose result feeds
`Module.concat`" rule will false-positive on `base_transformer.ex`'s own helper, which several
transformers use *correctly* (compute a fresh child-namespace, not reconstruct an existing one). See
Open Question 3 for the recommended, narrower design and the explicit tradeoff.

### Correction #3 — no CI exists yet; FOUND-16 is authoring a workflow from scratch, not adjusting one

`[VERIFIED: find .github -type f → no results, this session]`. LEARNINGS.md §2 lists
`.github/workflows/` as a surviving asset "if plan 01-08 lands before the rewrite begins" — it did
not land. **There is no `.github/workflows/*.yml` file in this repository at all.** FOUND-16 (CI
matrix) and D-12 (canonical-version-only text diff) are being designed on a blank slate, not modified
on an existing pipeline. This changes the planning shape: rather than "add a matrix leg," the task is
"author the first CI workflow, get the matrix and the D-12 conditional-skip logic right the first
time." See the CI Matrix section below for the concrete mechanism.

### Correction #4 — `usage_rules` 1.2.8 is vendored under `deps/`; its actual mechanism read directly

`[VERIFIED: deps/usage_rules/README.md, deps/usage_rules/lib/mix/tasks/*.ex — read this session]`. The
package is not a code generator for *new* prose about your own project — it is a **sync tool that
inlines/links other dependencies' pre-written `usage-rules.md` files** into a target file (typically
`AGENTS.md`) via a `:usage_rules` key in `mix.exs`'s `project/0`, run with `mix usage_rules.sync`. See
Open Question 7 for the full mechanism and what this means for FOUND-13/14/15's division of labour
between hand-written and tool-synced content.

## Summary

This phase builds instruments, not features: a renderer that shows exactly what the DSL generates,
a set of executable gates that reject three previously-invisible anti-patterns, and a namespace move
that every later phase's directory structure depends on. Four prior research documents
(STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md) already establish the *what* — this document
closes the gap to *how a planner writes executable tasks*, by reading the actual seam
(`BaseTransformer.create_module/3`, confirmed used by every one of the 9 transformers that create a
module), designing the concrete mix-task/capture mechanism D-06 requires, resolving the ambiguity in
how the golden-file ratchet is measured and where its check runs relative to D-12's CI-version split,
giving a testable (not speculative) design for the two Credo checks and the one non-Credo check
FOUND-08/09/10 require, and giving a concrete, evidence-based procedure for the D-13/D-14 big-bang
move including three breakage classes a find-and-replace misses (`mix.exs`'s doc groups and cheat
sheet filenames, `.dialyzer_ignore.exs`'s path-keyed entries, and the fact that "Commanded" the word
must NOT be globally renamed because D-15 keeps the `commanded do ... end` block name).

**Primary recommendation:** Build the renderer first and use it to snapshot the *current* (pre-rename)
generated output as a golden baseline before touching a single file for D-13/D-14 — then do the
big-bang move, re-render, and diff against that baseline as the move's own proof of
behaviour-neutrality. This makes Foundation dogfood its own first deliverable and gives the strongest
available evidence for "pure relocation, no behaviour change."

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
| --- | --- | --- | --- |
| DSL-output rendering (`mix ash_commanded.dump`) | Build/Dev tooling (Mix task) | — | Runs at `mix run`/developer-invocation time, not part of the compiled library's runtime surface |
| AST capture hook | Compile-time (Spark transformer pipeline) | Build tooling (consumes it) | Lives inside `BaseTransformer.create_module/3`, which executes during `mix compile` of a DSL-using module |
| Size/shape/reassembly gates | Build/CI tooling (ExUnit test + Credo) | — | Enforcement is a test-suite/static-analysis concern, not a runtime concern |
| `lib/` resource/domain split | Library source (compile-time DSL extension) | — | This *is* the library's own architecture, not tooling around it |
| AGENTS.md / usage_rules | Documentation / Dev tooling | — | Consumed by humans and coding agents, not by the running application |
| CI matrix | Build/CI tooling | — | GitHub Actions workflow, external to the library's runtime |

No browser/API/database tiers apply — this phase has no runtime-request-serving surface at all; every
capability here is compile-time, build-time, or documentation.

## Open Question 1 — Where exactly does the AST-capture hook attach?

### The seam is real and singular — verified

`[VERIFIED: lib/commanded/transformers/base_transformer.ex:70-74, and grep across
lib/commanded/transformers/*.ex — this session]`. Every transformer that creates a module routes
through one function:

```elixir
# lib/commanded/transformers/base_transformer.ex:70-74
@spec create_module(module(), Macro.t(), Macro.Env.t()) :: :ok
def create_module(module_name, ast, env) do
  Module.create(module_name, ast, Macro.Env.location(env))
  :ok
end
```

Confirmed callers (9 call sites, one per transformer that emits a module):
`generate_command_modules.ex:74`, `generate_commanded_application.ex:81`,
`generate_aggregate_module.ex:146`, `generate_projection_modules.ex:72`,
`generate_main_router_module.ex:134,138`, `generate_event_handler_modules.ex:102`,
`generate_event_modules.ex:73`, `generate_projector_modules.ex:126`. **This is the correct, and only,
seam** — D-06's premise holds exactly as stated.

### Recommended capture mechanism

Extend `create_module/3` (or a renamed/relocated equivalent under D-13's new namespace) to:

```elixir
def create_module(module_name, ast, env) do
  if Application.get_env(:ash_commanded, :capture_ast?, false) do
    :ets.insert(:ash_commanded_dump_capture, {module_name, ast})
  end
  Module.create(module_name, ast, Macro.Env.location(env))
  :ok
end
```

- **Flag:** `Application.get_env(:ash_commanded, :capture_ast?, false)` — a plain runtime
  `Application` env read, not `compile_env`. It must be readable *within the same running mix task
  invocation* that forces the recompile below, so it cannot be baked in at `create_module/3`'s own
  (long-past) compile time. Default `false` means a normal `mix compile`/`mix test` pays exactly one
  map lookup per generated module — negligible, matching D-06's "a normal build pays nothing."
- **Storage — what survives the compile boundary:** recommend a **named, public ETS table**
  (`:ash_commanded_dump_capture`), created by the mix task before it forces the recompile and read by
  the same task after. Rationale over the alternatives the open question raises:
  - *Process dictionary* works today (compilation of one file via `Code.compile_file/1` runs
    synchronously in the calling process) but breaks silently the moment any transformer adopts
    `Spark.Dsl.Transformer.async_compile/2` (confirmed to exist and be usable for this in FEATURES.md
    §3/§8) — which spawns a `Task`, a different process, whose dictionary the caller cannot read.
  - *A file* is unnecessary I/O for data that never needs to survive past one mix task invocation.
  - *An ETS table* survives across processes for free (no PID threading required) and is trivially
    cleaned up (`:ets.delete/1` at the end of the task, or simply let the table die with the mix
    task's own BEAM instance, since `mix ash_commanded.dump` is a fresh `mix` invocation each time).
- **Forcing a recompile of ONE target module from inside a mix task:**
  1. `Mix.Task.run("compile")` — ordinary incremental compile, so all of Ash/Spark/Commanded and
     every *other* module are loaded via the fast, cached path.
  2. Resolve the target's own source file with **no user-supplied path needed** — `Module.__info__(:compile)[:source]`
     on the already-loaded target module returns its absolute path (this is a standard, stable
     Elixir/Erlang mechanism — `:source` is populated by the compiler for every module). This lets
     `mix ash_commanded.dump MyApp.Widget` work from a bare module name, matching D-05's stated
     invocation shape.
  3. `Code.compiler_options(ignore_module_conflict: true)` — suppresses the "redefining module"
     warning Elixir would otherwise print when the same module names are compiled a second time in
     the same VM.
  4. Set the flag, create/clear the ETS table, then `Code.compile_file(source_path)` — this
     re-executes the target file's `defmodule ... use Ash.Resource, extensions: [...]` and re-runs
     the whole Spark transformer pipeline for it, *in-process*, so every `create_module/3` call along
     the way captures into the ETS table.
  5. Unset the flag immediately after.
  6. Enumerate which generated module names belong to the requested target by calling the (also new,
     FOUND-per-this-phase) `AshCommanded.Resource.Info`/`AshCommanded.Domain.Info` accessors on the
     freshly recompiled target module — this correctly scopes the render to "everything this DSL
     module generated" per FOUND-01, even if the fixture file that was recompiled happens to declare
     more than one DSL-using module.
  7. Render each captured AST via `Macro.to_string/1` + `Code.format_string!/1`, reusing the
     try/rescue fallback `scripts/render_generated.exs` already prototypes for AST that doesn't
     round-trip through the formatter cleanly (`[VERIFIED: scripts/render_generated.exs:70-78]`).
- **FOUND-03 (post-compile `debug_info` behind a flag):** this is a *separate* code path, not the
  capture mechanism above — it is exactly `scripts/render_generated.exs`'s existing `:beam_lib`
  approach (`[VERIFIED: scripts/render_generated.exs:17-44]`), promoted from a throwaway script into
  a flag on the same mix task (e.g. `--beam`). No new mechanism needed here beyond wiring it into the
  task; the script itself already handles the case Commanded's own aggregate has no `use` macro to
  worry about (the whole generated body is visible either way).
- **What this buys against the D-06-rejected alternative:** no `__ash_commanded_source__/0` function
  is ever injected into a generated module, so nothing pollutes the very output under review.

## Open Question 2 — How is the ratchet/budget machinery structured?

### Three distinct measurement axes on two distinct artifacts — do not conflate them

This is the first thing a planner must get right, because D-03's prose ("global caps: clause 10
lines, quote 40 lines") reads as one family but is actually two unrelated checks on two different
files:

| Axis | Measured on | Mechanism | Absolute ceiling? |
| --- | --- | --- | --- |
| Generated **clause** line count (FOUND-06) | **Rendered golden output** (`test/golden/**/*.golden`) | New size-budget test (below) | Yes — ~10 lines |
| **`quote` block** line count (FOUND-07) | **Generator source** (`lib/**/transformers/*.ex`) | Existing `Credo.Check.Refactor.LongQuoteBlocks`, already enabled — set `max_line_count: 40` | Yes — 40 lines |
| Generated **module** total line count | **Rendered golden output** | Same size-budget test as clause count | No absolute ceiling stated — ratchet only (per-golden, via the header) |

A `quote` block is generator-source syntax that no longer exists once code is rendered (rendering is
what expanding the macro *removes*), so "check the `quote` block size" can only ever be a check
against `.ex` files under `lib/`, never against a `.golden` file. Conversely "clause"/"module" size is
meaningless against generator source (a generator's own function bodies are not the emitted clauses).
Treat these as two separate, independently-verifiable pieces of Phase 1 work.

### Measuring clause span — verified this session, more precise than STACK.md's suggestion

STACK.md recommends walking every descendant node's `meta[:line]` via `Macro.postwalk` and taking
`max - min`. This has a real gap: bare literals (integers, atoms, strings) are **not** wrapped in
`{value, meta, context}` 3-tuples in Elixir's AST, so they carry no line metadata — a clause whose
last statement is a bare literal return value could be undercounted.

A more precise mechanism, confirmed by direct execution this session
(`[VERIFIED: elixir -e REPL probe, this session]`):

```elixir
Code.string_to_quoted!(source, columns: true, token_metadata: true)
```

With `token_metadata: true`, every `:def`/`:defp` node's metadata includes an explicit `end:` key
giving the exact line of its closing `end`:

```elixir
{:def, [end_of_expression: [...], do: [line: 2, column: 14], end: [line: 5, column: 3], line: 2, ...], [...]}
```

Clause span = `end_line - line + 1`, read directly off the node's own metadata — no tree walk needed,
no risk of missing a trailing bare literal. Recommend this over the postwalk-min/max approach.

### Where the check runs, and how it relates to D-12

**Not Credo.** Credo's `files:` mechanism is designed for hand-authored `.ex`/`.exs` source a human
edits directly; `.golden` files are machine-rendered artifacts reviewed via diff, not files anyone
free-types into. Recommend a **plain ExUnit test** (e.g. `test/ash_commanded/golden_budget_test.exs`)
that globs `test/golden/**/*.golden`, reads each file's own text, parses its `# gsd-budget:` header
line, measures clause/module size with the mechanism above, and asserts `measured <= declared` (also
asserting `declared <= 10` for `clause_max`, the FOUND-06 absolute ceiling; there is no absolute
ceiling to assert for `module_lines`, only the ratchet).

This test is a normal part of `mix test`, which already runs on **every** CI matrix leg (`cmd MIX_ENV=test
mix test` in the existing `check` alias, `[VERIFIED: mix.exs:209]`) — satisfying "the size gates must
run on every CI matrix leg" for free, with zero new CI wiring. It is independent of D-12's
formatter/version sensitivity because it only *parses* the committed golden text (Elixir's *parser* is
stable across the supported minor range; it is the *pretty-printer*'s exact output that varies between
minors) — it never regenerates anything.

**The actual text-diff test is separate**, and *that* is the one D-12 needs skipped on non-canonical
legs: a second test (e.g. `test/ash_commanded/golden_render_test.exs`) that calls the render pipeline
fresh and byte-diffs the result against the committed `.golden` file. Tag it (`@tag :canonical_version_only`)
and either (a) exclude the tag on non-canonical CI legs via `mix test --exclude canonical_version_only`,
or (b) check `System.version()` inside a `setup`/`@moduletag :skip` conditional and skip at runtime.
Either mechanism keeps the size-consistency test (above) running everywhere while the
formatter-sensitive text diff runs only on the one declared canonical version — this is the concrete
implementation of D-12.

### How growth is actually prevented — two mechanisms, not one

- **`--write`'s refusal (developer/CI-authoring-time gate, D-11):** before overwriting a `.golden`
  file, the mix task reads the *existing* committed file's header, measures the fresh render, and
  refuses to write if the fresh numbers are larger — naming the file and the exact header line to
  edit (D-04's remedy). This is where "never grow" is actually enforced.
- **The CI size test (verification-time gate, above):** does not need git history at all — it only
  asserts internal self-consistency (the committed body matches its own declared header, and the
  header itself respects FOUND-06's absolute ceiling). Its job is to catch a `.golden` file that was
  hand-edited (or regenerated by some other path) bypassing `--write`'s refusal logic entirely.

Both are needed: without the first, growth has no friction; without the second, a bypass of the first
goes undetected by CI.

## Open Question 3 — Custom Credo checks, concretely

### Two of the three checks belong in Credo (against `lib/`); the third does not (against `test/golden/`)

**FOUND-09 (`Code.string_to_quoted!`/`eval_string` in transformers) — a real Credo check.** STACK.md's
sketch is directly usable:

```elixir
defmodule AshCommanded.CredoChecks.NoRuntimeStringToAst do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [check: "Transformers must not build AST from interpolated strings (Rule 10)."]

  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({{:., _, [{:__aliases__, _, [:Code]}, fun]}, meta, _args} = ast, issues, issue_meta)
       when fun in [:string_to_quoted, :string_to_quoted!, :eval_string] do
    {ast, [format_issue(issue_meta, message: "...", trigger: fun, line_no: meta[:line]) | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}
end
```

Register in `.credo.exs` (paths update per D-13): `requires: ["lib/ash_commanded/credo_checks/**/*.ex"]`,
add the module to `checks: enabled:` with `priority: :normal` or higher (see the strictness caveat
below), exclude the checks directory from `mix.exs`'s `files:` so it never ships to hex consumers
(`[CITED: STACK.md]`, already recommended there).

**FOUND-10 (module-name surgery) — a real Credo check, but only a heuristic one, and it WILL
false-positive against `base_transformer.ex`'s own `get_module_prefix/1`.** Per Correction #2 above,
`Module.split |> ... |> Module.concat` is used both as the confirmed anti-pattern *and* as the
legitimate "compute a fresh child namespace" pattern the ARCHITECTURE.md AshOban precedent also uses.
No AST-local pattern can distinguish "reconstructing a value already available elsewhere" from
"deriving a genuinely new name" — that judgment needs the surrounding function's data flow, which is
outside what `Credo.Code.prewalk/2` sees per-node. Recommended design: flag **every** occurrence of
`Module.split/1` whose result flows (same pipe chain, or same local variable within ~5 statements)
into `Module.concat/1`, unconditionally — non-negotiably including `base_transformer.ex` itself. This
means Phase 1 must decide, for `get_module_prefix/1`, either (a) rewrite it to take the prefix from
somewhere already persisted (preferred, since several of its own callers are the ones doing legitimate
prefix computation and could instead receive an already-resolved value), or (b) keep it and add one
`# credo:disable-for-this-line`/file-level disable, D-02-compliant, naming which future phase revisits
it. Flag this decision explicitly to the planner rather than silently choosing.

**FOUND-08 (compile-time-known values reassembled at runtime, the `:erlang.++` class) — NOT a Credo
check; a plain ExUnit test against rendered output, same shape as the size-budget test in Open
Question 2.** The confirmed instance (LEARNINGS.md §1) is invisible in generator *source* and visible
only in the *rendered* output — Credo's `files:` mechanism exists to lint hand-authored `.ex` source a
human edits directly, and while it is *technically* possible to add `test/golden/**/*.golden` to
`.credo.exs`'s `included:` list and have a check inspect `source_file.filename` to scope itself to that
directory, doing so mixes an editor-feedback tool with a generated-artifact verification concern for no
benefit. Recommend instead: a pure function `AshCommanded.Dump.Lint.find_runtime_reassembly(ast) ::
[violation]` that walks for `{{:., _, [:erlang, :++]}, _, _}` (compiled `++`) or `{:++, _, [_, _]}`
where an operand is itself a literal list/keyword list (STACK.md's exact signature), called from a
plain ExUnit test that globs `test/golden/**/*.golden` — living beside, and structured identically to,
the size-budget test from Open Question 2. Same rationale: runs on every CI leg via `mix test`, no new
Credo/`.credo.exs` file-list surgery needed, and the checking function is directly unit-testable
without any Credo test harness at all.

**Credo strictness caveat, flagged not resolved:** `[VERIFIED: .credo.exs:49 (`strict: false`) and
mix.exs:208 (`"credo"`, no`--strict`flag) — read this session]`. PROJECT.md/LEARNINGS.md's prose
repeatedly says "Credo (strict)," but the actual configuration runs non-strict. `[ASSUMED]`: Credo's
non-strict mode still fails the build on `:normal`-or-higher priority issues (only `:low`-priority
issues are hidden/non-blocking without `--strict`) — this is training-knowledge, not verified against
Credo 1.7.19's source this session. Recommend the planner set `priority: :normal` or higher on every
new custom check regardless, sidestepping reliance on the exact strict/non-strict boundary, and treat
the "Credo (strict)" prose elsewhere in the planning docs as an inaccuracy to note, not a locked
behaviour to preserve unexamined.

## Open Question 4 — The seeded-violation harness

### Reconcile two readings of the ROADMAP.md success criterion

ROADMAP.md Phase 1 SC3 literally says each violation must "fail `mix check`... removing it turns the
build green again." Read strictly, that implies a real, temporary, in-tree violation and a real
`mix check` invocation — not a fixture permanently sitting in a directory `mix check` never sees. The
CONTEXT.md-suggested pattern ("a fixture directory excluded from the normal check run and exercised by
a meta-test that asserts the check fires") is the *regression-proof* version of the same idea, and the
two are complementary, not competing:

1. **Permanent regression tests (forever-green, run every CI leg):** for each of the five checks
   (clause-size, quote-size, runtime-reassembly, string-to-quoted, module-surgery), a small fixture
   string living in a location invisible to `mix compile`, `mix credo`, and ExUnit's own test
   discovery by construction — recommend `priv/seeded_violations/*.ex` (NOT under `lib/` — would be
   compiled; NOT under `test/` — would be swept by Credo's default `included:` glob AND by ExUnit's
   `*_test.exs` file discovery if misnamed; `priv/` is on neither `elixirc_paths` list
   `[VERIFIED: mix.exs:74-76]` nor Credo's default `included:` glob `[VERIFIED: .credo.exs:24-33]`).
   A single meta-test (`test/ash_commanded/seeded_violations_test.exs`) reads each fixture's raw text
   and calls the check's own pure function (`AshCommanded.Dump.Lint.find_runtime_reassembly/1`, or
   `Credo.Test.Case.run_check/2` + `assert_issue/2` for the two Credo checks, exactly the pattern
   STACK.md already documents) directly against that content, asserting a violation IS found. This
   proves each gate's *detection logic* is correct, permanently, without ever putting the tree in a
   red state.
2. **A one-time, evidenced proof during Phase 1's own execution (satisfies the roadmap's literal
   wording as VERIFICATION.md evidence, not as a permanent fixture):** for each of the five violations,
   the executor temporarily introduces it into a location `mix check` *does* sweep (e.g., temporarily
   append an oversized `quote` block to a scratch file under `lib/`, or temporarily drop a bad golden
   into `test/golden/`), runs `mix check`, captures the failure output naming the file/rule, reverts
   the change, and re-runs `mix check` to confirm green. This is recorded as verification evidence
   (screenshots/pasted output in VERIFICATION.md), not as a permanent test file.

Recommend both: (1) as permanent, automated regression coverage; (2) as a one-time, human-witnessed
proof-of-gate-works exercise whose output is the phase's verification evidence. Neither alone fully
satisfies both "provably still works in six months" and "the roadmap's literal words."

## Open Question 5 — The big-bang move (D-14), concretely

### Full file inventory to relocate/rename

`[VERIFIED: find lib -type f, this session]` — every file under `lib/commanded/` (18 transformer/verifier
files, 5 section files, 5 middleware files, ~15 other runtime modules) moves under `lib/ash_commanded/`
with `AshCommanded.Commanded.*` module names becoming `AshCommanded.Resource.*`/`AshCommanded.Domain.*`
per D-13. `AshCommanded.Commanded.Dsl` → `AshCommanded.Resource.Dsl`; `AshCommanded.Commanded.DomainDsl`
→ `AshCommanded.Domain.Dsl` (D-13's exact names). Submodule naming for transformers/verifiers/sections
below the two top-level Dsl modules is **not locked by D-13** — ARCHITECTURE.md §7's
`AshCommanded.Resource.Transformers.*`/`AshCommanded.Domain.Transformers.*` convention is the natural
precedent (mirrors `ash_graphql`) but is the planner's decision, not this research's to lock.

### Breakage classes beyond simple find-and-replace — evidenced, not just asserted

1. **`mix.exs`'s `spark.cheat_sheets` alias** — `[VERIFIED: mix.exs:194]` currently
   `"spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl"`. Must become a comma-separated list
   naming both new modules (also required independently by DOCS-04, but the *rename* breaks the
   existing single-module invocation even before DOCS-04's domain-coverage work is done).
2. **`mix.exs`'s `docs()` function** — `[VERIFIED: mix.exs:132-146]` `groups_for_modules:` names
   `AshCommanded.Commanded.Dsl`, `AshCommanded.Commanded.DomainDsl`, and three regexes
   (`~r/AshCommanded.Commanded.Sections/`, `~r/AshCommanded.Commanded.Transformers/`,
   `~r/AshCommanded.Commanded.Verifiers/`) plus `AshCommanded.Commanded.Info`. **This does not error on
   rename** — `mix docs` runs clean either way, it just silently stops matching anything and every
   module falls into an "ungrouped" bucket. This is exactly PITFALLS.md's "Looks Done But Isn't"
   shape: compiles fine, `mix docs` runs fine, the generated documentation is simply wrong. Must be
   updated in the same commit as the rename, verified by actually opening the generated docs output
   (a `mix compile`-only check will not catch this).
3. **Cheat-sheet output filenames** — `[VERIFIED: mix.exs:109,129]` `docs()`'s `extras:`/
   `groups_for_extras:` reference `cheatsheets/AshCommanded.Commanded.Dsl.cheatmd` by literal filename
   (`Spark.CheatSheet`'s mix task names output files after the extension module). After rename this
   becomes `AshCommanded.Resource.Dsl.cheatmd`, and DOCS-04 (domain cheat sheet, a *later*-phase item)
   will eventually add a second `AshCommanded.Domain.Dsl.cheatmd` — Phase 1 only needs the first
   renamed correctly; do not let the D-13 rename silently leave a reference to a cheat sheet file that
   no longer exists.
4. **`.dialyzer_ignore.exs`'s path-keyed entries** — `[VERIFIED: .dialyzer_ignore.exs, read this
   session]`. All four entries are keyed by literal path strings
   (`"lib/commanded/transformers/generate_aggregate_module.ex"`, etc.). Dialyzer's ignore-file
   matching is by exact path string. **After the move, these four entries silently stop matching**,
   and the pre-existing Dialyzer warnings they suppress reappear as *new* (unignored) findings,
   failing `mix dialyzer` — this is not cosmetic, it blocks `mix check`. Update all four paths in the
   **same commit** as the move.
5. **"Commanded" the word is not uniformly renamed — D-15 keeps `commanded do ... end`.** A careless
   repo-wide `sed s/Commanded/Resource/g` (or similar) would incorrectly rewrite the DSL block keyword
   itself, which D-15 explicitly locks as unchanged, and would also corrupt `scripts/compile_parity.sh`'s
   `EXPECTED_MODULES` array (`[VERIFIED: scripts/compile_parity.sh:19-26]`), whose entries
   (`AshCommanded.TestSupport.Parity.WidgetAggregate`, etc.) are derived from the **fixture's own**
   namespace, not `AshCommanded.Commanded.*`, and contain no occurrence of the word "Commanded" that
   needs changing at all. The rename must be scoped to specific, enumerated module-name occurrences
   (`AshCommanded.Commanded.Dsl` → `AshCommanded.Resource.Dsl` and its siblings), never a blind
   string substitution across the repo.
6. **Prose is out of scope for Phase 1, by the roadmap's own sequencing** — README.md, CLAUDE.md,
   `.claude/CLAUDE.md`, and `documentation/*.md` all reference the old module names in prose/code
   examples. DOCS-01/02 (reconciling CLAUDE.md) are explicit **Phase 7** requirements ("documentation
   is the last phase, not first," ROADMAP.md's own stated rationale). Phase 1 should not attempt to
   fix every prose reference — but should ensure AGENTS.md (this phase's own new deliverable) is
   written using the **new**, canonical names from the start, so Phase 1 does not add a second source
   of stale documentation alongside the pre-existing one.
7. **`test/`'s own fixtures must move in lockstep** — `test/support/widget.ex`, `test_domain.ex`,
   `context_widget.ex`, `custom_action_widget.ex`, `test/support/parity/parity_widget.ex`,
   `parity_domain.ex`, `test/support/commanded_app_case.ex` all reference the DSL extension module by
   name in `use Ash.Resource, extensions: [...]`/`use Ash.Domain, extensions: [...]`. Unlike items 2-4
   above, the compiler *does* catch a miss here immediately (undefined module), so this class of
   breakage is comparatively safe — but it must land in the same commit, or the suite does not compile
   at all, let alone stay green.

### Verifying the move as behaviour-neutral — the renderer proves its own foundation

Recommended sequencing within Phase 1 (not a locked decision, a concrete recommendation):

1. Build the renderer (D-05/D-06/D-18) **first**.
2. Use it to render and commit a snapshot of the **current** (`AshCommanded.Commanded.*`) generated
   output for the existing `test/support/parity/` fixture — this is the *pre-rename* baseline.
3. Perform the D-13/D-14 big-bang move.
4. Re-render the same fixture (now under its new module names) and diff the two renders.
5. An empty diff (or a diff differing only in trivially-renamed module-name literals inside the
   rendered text, e.g. a generated `@moduledoc` mentioning the DSL module by name) is the single
   strongest available proof that the move changed layout and naming only, not behaviour — stronger
   than "the test suite still passes," which proves *observable* behaviour is unchanged but says
   nothing about whether the generated *code itself* silently drifted in some way the existing tests
   don't happen to exercise.
6. Independently, confirm: full suite green (176+ tests), `mix check` green (this alone re-verifies
   items 4 and 7 above — Dialyzer will fail loudly if `.dialyzer_ignore.exs` wasn't updated, and the
   suite won't compile if a fixture wasn't updated), and `scripts/compile_parity.sh` green under both
   `MIX_ENV=dev` and `MIX_ENV=test` (re-proving cross-environment generation survived the move).

## Open Question 6 — `ex_dna` integration

`[ASSUMED — package name and exact config keys discovered via WebSearch this session, not via
Context7/official docs;`gsd_run query package-legitimacy check` does not support the `hex` ecosystem,
so no `[VERIFIED: npm registry]`-equivalent check could be run]`. Per hexdocs.pm (fetched via
WebFetch this session) and the earlier STACK.md research: current version **1.5.4** (STACK.md cites
1.5.1, already stale by two patch releases — re-verify at implementation time), MIT licensed, source
at `github.com/elixir-vibe/ex_dna`, ships a Credo plugin exposing full Type-I/II/III structural clone
detection, reusing Credo's already-parsed ASTs. Output formats: Credo-console (participates in the
normal `mix credo` report/exit-code, no special CI wiring needed beyond enabling it), JSON, HTML,
SARIF (useful for GitHub code-scanning annotations, not required for this milestone).

**Coexistence with the built-in `DuplicatedCode` check:** per Correction #1 above,
`Credo.Check.Design.DuplicatedCode` is **already disabled** — there is nothing to turn off. The task
is purely additive: register the plugin (exact key — `plugins: [ExDna]` or `plugins: [{ExDna, []}]`
depending on the plugin's own declared API, **not independently confirmed this session** — fetch
`hexdocs.pm/ex_dna/readme.html` directly via Context7/WebFetch at implementation time rather than
trusting this WebSearch-derived recollection) plus enabling whatever check module(s) the plugin
exposes in `checks: enabled:`.

**Package legitimacy:** see the Package Legitimacy Audit section below — recommend a
`checkpoint:human-verify` before `mix deps.get` adds it, per the `[ASSUMED]` package-name provenance
rule, regardless of STACK.md's MEDIUM-HIGH confidence rating (that confidence was also web-search
derived, not registry/Context7-verified).

## Open Question 7 — `usage_rules` generation

`[VERIFIED: deps/usage_rules/README.md, deps/usage_rules/lib/mix/tasks/usage_rules.sync.ex — vendored
at 1.2.8, read directly this session]`.

### What the tool actually does — it is a sync/aggregation tool, not a project-prose generator

`usage_rules` does not write new prose about *your own* project. It **inlines or links other
dependencies' own pre-written `usage-rules.md`/`usage-rules/*.md` files** into one target file, driven
entirely by a `:usage_rules` key added to `mix.exs`'s `project/0`:

```elixir
def project do
  [
    # ...
    usage_rules: usage_rules()
  ]
end

defp usage_rules do
  [
    file: "AGENTS.md",
    usage_rules: [:ash, :spark, :usage_rules],
    skills: [location: ".claude/skills"]  # optional; not required by FOUND-13..15
  ]
end
```

Running `mix usage_rules.sync` then writes/updates `AGENTS.md`, and — per the README's own words —
"the config is the source of truth: packages present in the file but absent from config are
automatically removed on each sync," so re-running it after a dependency bump keeps that section
current with zero manual editing.

### Division of labour for FOUND-13/14/15

- **FOUND-13** ("the library publishes generated LLM-facing usage rules") is about AshCommanded's own
  `usage-rules.md`, hand-authored at the repo root, describing *how to use AshCommanded's DSL* from a
  consumer's perspective — this is written BY the maintainers (optionally AI-assisted per the tool's
  own README recommendation: "have an agent begin the work... then aggressively prune and edit"), not
  generated by `mix usage_rules.sync` (which only *consumes* other packages' files, it does not author
  new ones about the current project). This file must be added to `mix.exs`'s hex `files:` list
  (`[VERIFIED: mix.exs:85]` currently `~w(lib mix.exs README.md LICENSE .formatter.exs)` — missing
  `usage-rules.md`, `documentation/`, `cheatsheets/`; the latter two are DOCS-05's explicit Phase 7
  item, but `usage-rules.md` itself is FOUND-13's and should be added now).
- **FOUND-14/15** (AGENTS.md: idiomatic Elixir, DSL conventions, transformer ordering, testing
  expectations, Spark API reference, `core` as worked reference) is majority hand-written prose
  specific to this project — `usage_rules.sync` cannot generate this content, it only pulls in *other*
  packages' (`:ash`, `:spark`) own usage-rules sections verbatim. Recommend AGENTS.md as a **hybrid**
  document: hand-written sections for project-specific conventions (the bulk of FOUND-14) plus a
  `usage_rules.sync`-managed block sourcing Ash/Spark's own usage rules (contributing toward FOUND-15's
  "Spark API reference," supplementing, not replacing, FEATURES.md's own hand-curated reference
  material this research already produced).
- **"Kept current" mechanism** — `[ASSUMED]`: whether `mix usage_rules.sync` exposes a check-only/dry
  run mode was not confirmed by reading its task source beyond the sync task itself (`usage_rules.list`
  and `usage_rules.docs` also exist, `[VERIFIED: deps/usage_rules/lib/mix/tasks/ file listing]`, but
  their exact behaviour was not read this session). Regardless of whether such a flag exists, the
  generic "regenerate, then `git diff --exit-code AGENTS.md`" pattern works without needing one — add
  `usage_rules.sync` (or an equivalent check) as a step in the `check` alias or a dedicated CI step,
  and fail if it produces an uncommitted diff.

## Standard Stack (delta only — see STACK.md/FEATURES.md for the full picture)

| Library | Version (verified this session) | Purpose | Confidence |
| --- | --- | --- | --- |
| `credo` | 1.7.19 resolved `[VERIFIED: mix.lock]` (STACK.md's 1.7.18 is one patch stale) | Host for all custom checks | HIGH |
| `sourceror` | 1.12.2 resolved `[VERIFIED: mix.lock]`, project pin still `~> 1.8` `[VERIFIED: mix.exs:54]` — bump confirmed still needed | AST-shape traversal for custom checks | HIGH |
| `spark` | 2.7.2 resolved `[VERIFIED: mix.lock]` | Already the version all four prior research docs plan against | HIGH |
| `usage_rules` | 1.2.8 resolved `[VERIFIED: mix.lock]`, already `only: [:dev]` `[VERIFIED: mix.exs:67]` | AGENTS.md sync tool + own usage-rules publishing | HIGH |
| `ex_dna` | 1.5.4 current per hexdocs (WebFetch this session) | Structural clone detection, Credo plugin | `[ASSUMED]` — package name from WebSearch, not Context7/registry-verified |

**Installation (dev/test only, no runtime dependency added):**

```elixir
{:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false}
# bump existing pin:
{:sourceror, "~> 1.12", only: [:dev, :test], runtime: false}
```

## Package Legitimacy Audit

| Package | Registry | Age/Version | Downloads | Source Repo | Verdict | Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| `ex_dna` | hex.pm | v1.5.4, last updated 2026-07-17 per hex.pm (WebFetch this session) | Reported figures were internally inconsistent across the same fetch (7-day count exceeded 30-day count) — treat the exact numbers as unreliable, not the package's existence | `github.com/elixir-vibe/ex_dna`, MIT | `[ASSUMED]` — not run through `package-legitimacy check` (tool has no `hex` ecosystem support); real GitHub repo with commit history exists per STACK.md's independent read | `checkpoint:human-verify` before `mix deps.get` adds it — planner must insert this gate |
| `sourceror` (version bump only) | hex.pm | 1.12.2, already a resolved transitive-turned-direct dependency `[VERIFIED: mix.lock]` | N/A — not a new package | Existing, already trusted | OK | Approved — this is a pin bump on an already-installed package, not a new install |

**Packages removed due to `[SLOP]` verdict:** none.
**Packages flagged as suspicious `[SUS]`/`[ASSUMED]`:** `ex_dna` — planner must add a
`checkpoint:human-verify` task before the `mix deps.get`/`mix.exs` edit that installs it, and should
independently re-confirm current version/maintenance status at that point rather than trusting this
document's numbers, which are already one session stale by definition.

## Architecture Patterns

Defer entirely to ARCHITECTURE.md §7 for the `lib/` layout rationale (already HIGH confidence, sourced
from `ash_graphql`/`ash_oban`/`reactor` read directly) and §1-§6 for the `__using__`/`.Info`/transformer
design that Phase 1 does *not* itself implement (that is Phase 4's aggregate work) but whose
*directory shape* Phase 1's D-13/D-17 move must anticipate so Phase 4 doesn't have to re-shuffle
directories a second time. The one addition from this session: confirm the recommended split's
top-level shape against what already exists —

```text
lib/ash_commanded/
  resource/
    dsl.ex              # AshCommanded.Resource.Dsl (was Commanded.Dsl)
    info.ex             # NEW — zero .Info modules exist today, confirmed [VERIFIED: find lib -iname '*info*' → none, this session, consistent with SUMMARY.md's independent finding]
    sections/
    transformers/
    verifiers/
  domain/
    dsl.ex              # AshCommanded.Domain.Dsl (was Commanded.DomainDsl)
    info.ex             # NEW
    transformers/
    verifiers/
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
| --- | --- | --- | --- |
| Golden-file diff/update workflow | A snapshot-testing library (`mneme`, `assert_value`) | Hand-rolled file-based harness (`test/golden/*.golden` + `File.read!`/`File.write!` + a diff helper) | Both real candidates embed the expected value as a literal *inside the test file*, unworkable for 300+-line renders that need PR-reviewable diffs `[CITED: STACK.md]` |
| "At most one X" / "unique name" DSL validation | Hand-written `ValidateXNames`/`ValidateXSingleton` verifiers | `identifier:` on the Entity, `singleton_entity_keys` on the Section/Entity | Spark auto-generates this; hand-writing it duplicates machinery Spark already runs `[CITED: FEATURES.md §1, §6]` |
| `.Info` module accessor boilerplate | Hand-written `def commands(resource), do: Extension.get_entities(...)` per section | `use Spark.InfoGenerator, extension: ..., sections: [...]` | One line replaces N hand-written getters, always in sync with the DSL's actual section list `[CITED: FEATURES.md §5]` |
| "No double-handling" (Rule 9 / FOUND-12) | Any attempt at a fully-mechanical check | A reviewer checklist item in AGENTS.md, stated as having no mechanical check | STACK.md Rule 5: this is a data-flow-ownership judgment (does the caller already hold this value?) that no AST-shape tool can answer; a narrow, non-blocking proxy (flag `Macro.prewalk/postwalk` calls inside a transformer as a review trigger) is the most that can be mechanized, and it is a nudge, not enforcement |

**Key insight:** every "Don't Hand-Roll" item above already has an off-the-shelf or Spark-native
answer *except* Rule 9, which genuinely has none — Phase 1's job for FOUND-12 is to say so plainly in
AGENTS.md, not to build a check that looks like it works but doesn't.

## Runtime State Inventory

This phase is a rename/refactor (D-13/D-14: every `lib/commanded/*` file relocates and every
`AshCommanded.Commanded.*` module renames), so this section is required.

| Category | Items Found | Action Required |
| --- | --- | --- |
| Stored data | None — no database/datastore persists these module names; this is a compile-time DSL rename with no runtime data layer involved | None |
| Live service config | None — no external service (n8n, Datadog, etc.) references these Elixir module names | None |
| OS-registered state | None — no Task Scheduler/pm2/systemd registration references these module names | None |
| Secrets/env vars | None directly. Noted for completeness: no external consumer of the published 0.2.0 DSL needs to migrate, since backwards compatibility with 0.2.0 is explicitly out of scope (`[CITED: PROJECT.md → Out of Scope]`) and `core`'s own migration is deferred to the next milestone — so there is no live consumer whose code breaks from this rename | None |
| Build artifacts / installed packages | **`.dialyzer_ignore.exs`'s four path-keyed entries** `[VERIFIED: .dialyzer_ignore.exs]` reference the OLD `lib/commanded/...` paths and go stale the moment files move — this is a genuine, easily-missed break (see Open Question 5, breakage class 4). Also: stale compiled `.beam` artifacts for the old module names may linger in `_build/dev`/`_build/test` after the move; PITFALLS.md's own documented "stale-BEAM" class of bug (Pitfall 11) makes a `mix clean && mix compile` a cheap, worthwhile verification step post-move even though the manifest-based incremental compiler is expected to handle a plain rename correctly | Update all four `.dialyzer_ignore.exs` path strings in the SAME commit as the move; run `mix clean && mix compile` once post-move as a verification step, not a required fix |

## Common Pitfalls

Defer to PITFALLS.md for the full catalogue (Pitfalls 15-17 are this phase's direct assignment: spurious
warnings/bad stacktraces from generated code, `Module.create/3` losing caller env, compile-time
dependency cascades). One addition from this session's direct reading:

### Pitfall: the module-name-surgery check will fire on the seam it's meant to protect

**What goes wrong:** implementing FOUND-10 as "flag any `Module.split` feeding `Module.concat`" and
being surprised when it immediately flags `base_transformer.ex`'s own `get_module_prefix/1` helper —
the very file the D-06 capture hook lives in.
**Why it happens:** the same AST shape (split, then concat) is both the anti-pattern *and* the
legitimate "derive a fresh child namespace" idiom (confirmed precedent: `ash_oban`'s
`define_action_workers.ex:33-38`, `[CITED: ARCHITECTURE.md §4]`).
**How to avoid:** decide, explicitly and up front, whether `get_module_prefix/1` itself is rewritten in
Phase 1 (to source its prefix from persisted state where callers already have it available) or is kept
with a documented, D-02-compliant suppression. Do not let this be discovered mid-implementation as a
surprise Credo failure.
**Warning signs:** the Credo check passes cleanly in a first draft that was only tested against the
one confirmed defect site (`generate_aggregate_module.ex:244-247`) and not against the whole `lib/`
tree, including its own new checks directory and `base_transformer.ex`.

## Code Examples

### Clause-span measurement (verified this session)

```elixir
{:def, meta, _} = def_node
start_line = meta[:line]
end_line = meta[:end][:line]
clause_span = end_line - start_line + 1
```

### AST capture flag check inside the shared codegen helper

```elixir
def create_module(module_name, ast, env) do
  if Application.get_env(:ash_commanded, :capture_ast?, false) do
    :ets.insert(:ash_commanded_dump_capture, {module_name, ast})
  end
  Module.create(module_name, ast, Macro.Env.location(env))
  :ok
end
```

### Golden header format (per D-10/specifics)

```elixir
# gsd-budget: clause_max=6 module_lines=48
defmodule MyApp.Commands.RegisterUser do
  # ... rendered output ...
end
```

## State of the Art

| Old Approach (this repo, today) | Recommended (this phase) | Impact |
| --- | --- | --- |
| No renderer; generated code only ever readable by mentally expanding macros | `mix ash_commanded.dump`, pre- and post-compile views | Makes the render-and-approve method possible at all |
| `Credo.Check.Design.DuplicatedCode` believed enabled (it is not) | `ex_dna` added, nothing to disable | Corrects a factual premise in CONTEXT.md before the planner acts on it |
| Golden-file convention: none exists | Hand-rolled `test/golden/*.golden` + budget header + ratchet | Standard pattern already proven in this ecosystem for large generated artifacts (`ash_postgres`'s migration-snapshot mechanism, `[CITED: ARCHITECTURE.md §6]`) |
| `lib/commanded/` flat namespace | `lib/ash_commanded/{resource,domain}/` split | Matches every mature Ash extension inspected (`ash_graphql`, `ash_json_api`, `ash_oban`) |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
| --- | --- | --- | --- |
| A1 | `ex_dna` package name/current-ness, and its exact `.credo.exs` plugin-registration key | Open Q6, Package Legitimacy Audit | Wrong config key wastes an implementation cycle; wrong/hallucinated package name would fail `mix deps.get` outright (low risk, self-evident failure) — mitigated by the recommended `checkpoint:human-verify` |
| A2 | Credo's non-strict mode still fails the build on `:normal`+ priority issues (only `:low` is hidden without `--strict`) | Open Q3 | If wrong, newly-added custom checks might not actually block `mix check` despite appearing to "work" in isolated `Credo.Test.Case` tests — recommend the planner explicitly verify this with one deliberately-`:normal`-priority seeded violation run through the *real* `mix check` alias, not just the unit test, before relying on it |
| A3 | `mix usage_rules.sync` has no built-in check/dry-run mode (only its `sync` behaviour was read; `list`/`docs` tasks exist but were not read this session) | Open Q7 | Low risk — the "regenerate + `git diff --exit-code`" fallback works regardless |
| A4 | Elixir AST bare-literal line-metadata gap (integers/atoms/strings carry no `meta[:line]`) makes STACK.md's postwalk-min/max approach undercount in some cases | Open Q2 | Low risk to correctness of the recommendation (the `token_metadata: true`/`end:` mechanism was directly executed and verified this session), but the *characterization of the gap in the alternative* is based on general Elixir AST knowledge, not a constructed counter-example proving the undercount in practice |

## Open Questions

1. **Exact submodule naming under `lib/ash_commanded/{resource,domain}/`** (e.g.
   `AshCommanded.Resource.Transformers.GenerateCommandModules` vs. some shorter scheme) — not locked
   by D-13, ARCHITECTURE.md's `ash_graphql`-mirroring convention is the natural default; planner should
   pick one and state it once, since ~30 files depend on the answer being consistent.
2. **Whether `test/commanded/` (the test directory, mirroring the old `lib/commanded/` layout) should
   also be renamed/restructured in the same big-bang move**, and whether to adopt ARCHITECTURE.md §6's
   one-verifier-per-test-file convention at the same time or defer that convention change to a later
   phase. Compounding two structural changes in one phase raises the diff size but avoids touching the
   same files twice.
3. **`ex_dna`'s exact `.credo.exs` integration snippet** — fetch `hexdocs.pm/ex_dna/readme.html`
   directly (Context7 or WebFetch) at implementation time rather than trusting this document's
   WebSearch-derived recollection of the plugin registration key.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
| --- | --- | --- | --- | --- |
| Elixir | Everything | ✓ | 1.18.4 `[VERIFIED: mix.lock resolution + prior research]` | — |
| Erlang/OTP | Everything | ✓ | 27 | — |
| `ex_dna` (new dep) | FOUND-11 | ✗ (not yet in `mix.lock`) | Target `~> 1.5` | None needed — install is the task itself; if `mix deps.get` fails, fall back to Credo's built-in `DuplicatedCode` re-enabled as a lesser substitute and document the gap |
| GitHub Actions | FOUND-16 | ✗ — `[VERIFIED: no`.github/workflows/*`exists, this session]` | N/A | None — must be authored from scratch, not a fallback scenario |

**Missing dependencies with no fallback:** GitHub Actions workflow file — must be created, not a
degraded-mode scenario.
**Missing dependencies with fallback:** `ex_dna` — if it fails to install/resolve, `DuplicatedCode`
re-enabled is a documented, weaker fallback (Type-I-only, per STACK.md).

## Validation Architecture

### Test Framework

| Property | Value |
| --- | --- |
| Framework | ExUnit (stdlib) `[VERIFIED: test/test_helper.exs is exactly ExUnit.start(), mix.exs]` |
| Config file | `test/test_helper.exs` — no exclusions, no fixed seed `[CITED: LEARNINGS.md §2]` |
| Quick run command | `mix test` (176+ tests today, runs in seconds per LEARNINGS.md's own stability claims) |
| Full suite command | `mix test` (no separate fast/slow split exists yet; recommend the new golden-render text-diff test be the one thing tagged for exclusion on non-canonical CI legs, not a general slow/fast split) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
| --- | --- | --- | --- | --- |
| FOUND-01/02/05 | `mix ash_commanded.dump` renders pre-`Module.create/3` AST, `--write` updates golden | integration (mix task invoked from a test) | `mix test test/ash_commanded/dump_task_test.exs` | ❌ Wave 0 |
| FOUND-03 | `--beam` flag renders post-compile `debug_info` | integration | same file, tagged case | ❌ Wave 0 |
| FOUND-04 | Golden text diffed in CI, canonical-version-only | integration, tagged `:canonical_version_only` | `mix test test/ash_commanded/golden_render_test.exs` | ❌ Wave 0 |
| FOUND-06 | Clause >10 lines fails | unit, every CI leg | `mix test test/ash_commanded/golden_budget_test.exs` | ❌ Wave 0 |
| FOUND-07 | `quote` block >40 lines fails | static analysis (Credo) | `mix credo` (config change only, `LongQuoteBlocks` already exists) | N/A — config change, no new test file |
| FOUND-08 | Runtime reassembly of compile-time-known values fails | unit, every CI leg | `mix test test/ash_commanded/golden_budget_test.exs` (same file as FOUND-06, or a sibling) | ❌ Wave 0 |
| FOUND-09 | `Code.string_to_quoted!`/`eval_string` in transformers fails | static analysis (Credo custom check) + `Credo.Test.Case` regression | `mix credo`, `mix test test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs` | ❌ Wave 0 |
| FOUND-10 | Module-name surgery fails | static analysis (Credo custom check) + `Credo.Test.Case` regression | `mix credo`, `mix test test/ash_commanded/credo_checks/no_module_name_surgery_test.exs` | ❌ Wave 0 |
| FOUND-11 | Structural duplicate detection | static analysis (`ex_dna` via Credo) | `mix credo` | N/A — dependency + config, no new test file |
| FOUND-16 | CI matrix, current + 2 minors | CI config (not a test) | `.github/workflows/ci.yml` exists and green on 3 legs | ❌ Wave 0 (file doesn't exist at all — Correction #3) |
| FOUND-17/D-13/D-14 | Big-bang relocation, behaviour-neutral | integration — pre/post-move golden diff (Open Q5) + full suite | `mix test`, `./scripts/compile_parity.sh`, manual golden diff | Partially — `compile_parity.sh` exists, golden diff mechanism is new |
| FOUND-18/D-06 | Shared helper sets `file:`/`line:`, captures AST behind flag | unit — a deliberate error in generated code reports a real `file:`/`line:` | `mix test test/ash_commanded/base_transformer_test.exs` (extend existing coverage) | Existing file — extend, don't recreate `[VERIFIED: base_transformer.ex has no visible test file in the earlier`find lib -type f` output — check `test/commanded/transformers/`for its actual test location before planning]` |

### Sampling Rate

- **Per task commit:** `mix test` (fast, seconds-scale per LEARNINGS.md).
- **Per wave merge:** `mix check` (format, `compile --warnings-as-errors`, credo, full test, `compile_parity.sh`, dialyzer, `gen.docs`) `[VERIFIED: mix.exs:205-213]`.
- **Phase gate:** `mix check` green on the canonical Elixir version (golden text diff runs) AND on
  every other matrix leg (golden text diff skipped, size/lint gates still run) before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `test/ash_commanded/dump_task_test.exs` — covers FOUND-01/02/03/05
- [ ] `test/ash_commanded/golden_render_test.exs` — covers FOUND-04, tagged `:canonical_version_only`
- [ ] `test/ash_commanded/golden_budget_test.exs` — covers FOUND-06/08 (size + reassembly gates over `test/golden/**/*.golden`)
- [ ] `test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs` — covers FOUND-09
- [ ] `test/ash_commanded/credo_checks/no_module_name_surgery_test.exs` — covers FOUND-10 (with the explicit `base_transformer.ex` false-positive decision made first, see Pitfall above)
- [ ] `test/ash_commanded/seeded_violations_test.exs` — covers ROADMAP.md SC3's regression-proof half
- [ ] `test/ash_commanded/disable_phase_citation_test.exs` — covers D-02 (parses all `# credo:disable-for-this-file` phase citations, fails on stale/absent phases)
- [ ] `.github/workflows/ci.yml` — does not exist at all (Correction #3); covers FOUND-16
- [ ] `priv/seeded_violations/*.ex` fixtures (5 files, one per gate) — inputs to the seeded-violations test, not tests themselves

## Security Domain

`security_enforcement` is enabled (`security_asvs_level: 1`) in `.planning/config.json`, so this
section is included per the standard contract, though this phase has no runtime request-serving
surface (no browser/API/auth layer — see Architectural Responsibility Map above).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
| --- | --- | --- |
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | No session surface |
| V4 Access Control | No | No access-controlled surface |
| V5 Input Validation | Marginal | `mix ash_commanded.dump <Module>` takes a module-name CLI argument; validate it resolves to a real, loaded module before attempting `Module.__info__/1` calls, failing with a clear error rather than a raw `UndefinedFunctionError` |
| V6 Cryptography | No | Not applicable |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
| --- | --- | --- |
| Supply-chain risk from a new dev dependency (`ex_dna`) | Tampering | Package Legitimacy Audit above; `checkpoint:human-verify` before install; dev/test-only (`only: [:dev, :test], runtime: false`) so it never ships in the compiled application even if compromised |
| `Code.compile_file/1` invoked by the dump mix task on an arbitrary module-derived path | Tampering (arbitrary code execution if the path is attacker-influenced) | Not a realistic external-facing risk — this is a local developer/CI tool operating on the developer's own already-trusted source tree, not a request-serving surface; no additional mitigation needed beyond what already applies to running `mix compile` at all |
| Dynamic atom creation from user-declared DSL names (a pattern this phase's own module-name checks touch, per PITFALLS.md Pitfall 21) | Denial of Service (unbounded atom table) | Every module name involved in this phase's tooling originates from compile-time, DSL-author-written literals (command/event/resource names), never from runtime/external input — no `String.to_atom/1` on untrusted data anywhere in the renderer or gates as designed above |

## Sources

### Primary (HIGH confidence — read directly this session)

- `lib/commanded/transformers/base_transformer.ex` — the confirmed capture seam
- `lib/commanded/transformers/*.ex` (all 9) — `create_module/3` call-site grep; `Module.split`/`Module.concat` grep (Correction #2)
- `scripts/render_generated.exs`, `scripts/compile_parity.sh` — existing prototypes this phase promotes
- `.credo.exs` — full read; Corrections #1
- `.dialyzer_ignore.exs` — full read; Open Q5 breakage class 4
- `mix.exs` — full read; Open Q5 breakage classes 1-3, `files:` list, `check` alias, strictness caveat
- `deps/usage_rules/README.md`, `deps/usage_rules/lib/mix/tasks/usage_rules.sync.ex` — Open Q7
- `deps/spark/lib/spark/test.ex` — `Spark.Test` docstring, confirms `assert_raise` gap and its fix
- `elixir -e` REPL probe (this session) — `token_metadata: true`'s `end:` line metadata, Open Q2
- `find .github -type f`, `find lib -type f`, `find test/support/parity -type f` — Correction #3, file inventories
- `.planning/CONTEXT.md`, `REQUIREMENTS.md`, `STATE.md`, `ROADMAP.md`, `PROJECT.md`, `LEARNINGS.md` — full reads

### Secondary (MEDIUM confidence)

- `.planning/research/STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md` — prior-session
  research, cited throughout rather than re-derived, per this session's explicit instruction not to
  repeat their findings
- hexdocs.pm/ex_dna/readme.html (via WebFetch, this session) — version/license/output-format claims

### Tertiary (LOW confidence, `[ASSUMED]`, flagged for confirmation)

- `ex_dna`'s exact `.credo.exs` plugin-registration key (Open Q6, Assumption A1)
- Credo non-strict-mode exit-code semantics for `:normal`-priority issues (Open Q3, Assumption A2)
- `mix usage_rules.sync`'s dry-run/check-mode existence (Open Q7, Assumption A3)

## Metadata

**Confidence breakdown:**

- Foundation mechanism designs (Open Q1-Q5, Q7): MEDIUM-HIGH — every primitive cited is verified this
  session; the assembled *design* (mix task, ETS capture, two-tier test split) is a recommendation
  built from those primitives, not itself an observed fact, since none of these files exist yet
- `ex_dna` integration (Open Q6): LOW-MEDIUM — package identity and exact config key are web-search
  derived and explicitly flagged `[ASSUMED]`
- Big-bang move risk inventory (Open Q5): HIGH — every breakage class is a direct file read with a
  line citation, not an inference

**Research date:** 2026-09-15
**Valid until:** 30 days for the Elixir/Spark/Credo primitives (stable ecosystem); re-verify `ex_dna`'s
version/config immediately before use regardless of this window, since it was never independently
confirmed above WebSearch confidence.
