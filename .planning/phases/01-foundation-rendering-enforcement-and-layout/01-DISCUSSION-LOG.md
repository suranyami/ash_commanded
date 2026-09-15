# Phase 1: Foundation — Rendering, Enforcement and Layout - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-15
**Phase:** 1-Foundation — Rendering, Enforcement and Layout
**Areas discussed:** Gate staging, Renderer surface and output, Golden renders (fixtures and granularity), Namespace and lib/ layout

---

## Gate staging

### How should the gates behave, given today's code fails them?

| Option | Description | Selected |
|--------|-------------|----------|
| Scope by what exists | Output gates run only against committed goldens; source gates use a shrinking allowlist. Both blocking day one. | |
| Per-file disables, deleted as rewritten | Extend the existing `credo:disable-for-this-file` idiom; delete a line as each component lands. | ✓ |
| Advisory now, blocking later | Gates report but do not fail until a Phase 7 flip. | |

**Notes:** Chosen because it matches an idiom already in five files and keeps suppression visible at
the offence. Claude had flagged the counter-risk that 15 existing disables already cite archived
phase numbers — addressed by the next question rather than by rejecting the option.

### How do we stop the disable comments drifting again?

| Option | Description | Selected |
|--------|-------------|----------|
| Machine-checked format | A test parses every disable, requires a phase reference, and fails when that phase is absent from the roadmap or complete. | ✓ |
| Documented convention only | Fix the 15, document the format in AGENTS.md, rely on review. | |
| Fix the 15, add a Phase 7 sweep | Re-point now; assert zero disables remain at the end. | |

**Notes:** Repairs the existing 15 as a side effect — all would fail until re-pointed. Consistent
with the milestone-level decision to make gates executable rather than prose.

### How should the size budgets be expressed?

| Option | Description | Selected |
|--------|-------------|----------|
| Ratchet + absolute ceiling | Goldens record measured sizes; may shrink or hold, never grow. Global caps as ceilings. | ✓ |
| Fixed global numbers | One set of numbers for everything. | |
| Per-component budgets in config | Each component declares its own with justification. | |

**Notes:** Rejected fixed numbers because a component landing at 3 lines could drift to 9 unnoticed;
rejected per-component config because budgets then become negotiable exactly when a gate matters.

### When a render must exceed its budget, how is that authorised?

| Option | Description | Selected |
|--------|-------------|----------|
| Raise it in the diff, with a reason | Edit the number in the golden's header plus a one-line reason; visible in the PR diff. | ✓ |
| Same machine-checked phase annotation | Reuse the disable mechanism. | |
| Never raised — escalate instead | Hitting a budget stops work pending a recorded decision. | |

**Notes:** Deliberately did NOT reuse the phase-annotation mechanism from the earlier question — a
Credo disable is temporary and should expire with its phase, while a legitimate budget raise is
permanent and would be wrongly forced out when that phase completed.

---

## Renderer surface and output

### What do you point `mix ash_commanded.dump` at?

| Option | Description | Selected |
|--------|-------------|----------|
| A DSL module, renders all it generated | Point at a resource or domain; `--only` narrows. | ✓ |
| A generated module directly | What `scripts/render_generated.exs` does today. | |
| Either, detected | Accept both forms and infer. | |

**Notes:** Matches the real loop — "I changed the command transformer, show me what a resource
generates now".

### How is the pre-`Module.create/3` AST captured?

| Option | Description | Selected |
|--------|-------------|----------|
| Helper captures, env-gated | FOUND-18's shared codegen helper stashes AST behind a flag; dump forces a recompile. | ✓ |
| Embed in dev/test BEAMs only | `__ash_commanded_source__/0` in every generated module under :dev/:test. | |
| Embed always | Available everywhere, ships in every BEAM. | |

**Notes:** The embed option would make dumping instant with no recompile, but the extra function
then appears in the post-compile `:beam_lib` view and pollutes the output being reviewed. That
downside decided it.

### How should the dump task relate to the golden files?

| Option | Description | Selected |
|--------|-------------|----------|
| Diff when a golden exists, else full render | Zero-flag behaviour matches the common case; `--write` updates. | ✓ |
| Explicit modes | Bare prints, `--diff` compares, `--write` updates. | |
| Two separate tasks | `dump` renders; `golden` compares and updates. | |

**Notes:** The common case would otherwise need `--diff` several hundred times this milestone.

### Published, or dev-only tooling?

| Option | Description | Selected |
|--------|-------------|----------|
| Published, a real feature | Ships and is documented; consumers can dump their own resources. | ✓ |
| Dev-only tooling | Excluded from the package. | |
| Published but undocumented | Available, no compatibility promise. | |

**Notes:** Knock-on effects recorded: adds a Phase 7 documentation obligation, and lets `core` use
the renderer during the migration milestone.

---

## Golden renders: fixtures and granularity

### What are the goldens generated from?

| Option | Description | Selected |
|--------|-------------|----------|
| Grow `test/support/parity/` | Reuses a dependency-free, data-layer-free tree already on the `:dev` elixirc path. | ✓ |
| New dedicated golden fixture set | Separate tree, keeps parity to its existing job. | |
| Reuse the functional ETS fixtures | Render from the resources tests actually dispatch through. | |

**Notes:** Extends the mechanism that turned the dev compiler into a reviewer of generated code.
Cost accepted: `compile_parity.sh`'s explicit module list must grow, and every dev compile builds
the fixtures.

### How do we stop `--write` becoming a rubber stamp?

| Option | Description | Selected |
|--------|-------------|----------|
| Friction only on regression | Accepts improvements freely; refuses when a budget would grow. | ✓ |
| Explicit approval marker | Goldens carry approver and date. | |
| The PR diff is the control | No tool friction at all. | |

**Notes:** The PR-diff option was weakened by the project's situation — for a solo upstream
maintainer the reviewing PR may be your own, minutes after running `--write`.

### What granularity, and where?

| Option | Description | Selected |
|--------|-------------|----------|
| One file per generated module, foldered per fixture | `test/golden/<fixture>/<module>.golden`, each with its own budget line. | ✓ |
| One file per fixture | Everything a resource generates in one file. | |
| One file per generated module, flat | No folders. | |

**Notes:** Driven by the ratchet decision — one budget line cannot describe five modules.

### How do goldens and the three-version CI matrix coexist?

| Option | Description | Selected |
|--------|-------------|----------|
| Diff on one canonical version | Text comparison pinned; size gates still run on every leg. | ✓ |
| Per-version goldens | One set per Elixir version. | |
| Normalise the render | Post-process into a version-insensitive canonical form. | |

**Notes:** Raised by Claude as a collision between FOUND-04 and FOUND-16 that would otherwise
surface as a mystery CI failure — the render comes from `Macro.to_string/1` + `Code.format_string!/1`,
both version-sensitive. Normalisation was rejected as the "if this feels tricky we are
overcomplicating something simple" smell.

---

## Namespace and lib/ layout

### What happens to the namespace?

| Option | Description | Selected |
|--------|-------------|----------|
| Flatten and conventionalise | `AshCommanded.Resource.Dsl` / `.Domain.Dsl` under `lib/ash_commanded/`. | ✓ |
| Keep names, fix directories only | Module names unchanged; only files move. | |
| Keep everything, add the split inside | Subdirectories under today's `lib/commanded/`. | |

**Notes:** A public API break, licensed by PROJECT.md's decision to break freely on 0.x while 0.2.0
adoption is negligible. Nearly free now, expensive after 1.0.

### When does the move happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Move only what survives | Phase 1 moves the files that outlive the rewrite; doomed generators are deleted in place. | |
| Big-bang move in Phase 1 | Everything relocates and renames at once. | ✓ |
| Skeleton only in Phase 1 | Create directories; files move per phase. | |

**Notes:** Chosen against Claude's recommendation. Accepted cost: roughly ten generator files are
relocated and then deleted within five phases. Accepted in exchange for never working in a
half-migrated tree.

### Does the DSL block stay `commanded do`?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `commanded do` | The section names what is being integrated, as `postgres do` and `graphql do` do. | ✓ |
| Rename for consistency | Match the flattened namespace. | |

---

## Claude's Discretion

- Prefer configuring Credo's existing checks over writing custom ones wherever a built-in covers the
  rule. Stated before the discussion and not objected to.
- AGENTS.md's shape and prescriptiveness; how `usage_rules` output is generated and kept current;
  the exact Elixir/OTP versions in the CI matrix. Offered as further gray areas and declined.

## Deferred Ideas

- Postgres-backed EventStore example — already deferred to the migration milestone in REQUIREMENTS.md.
- Reverting `workflow.use_worktrees: false` — housekeeping once this branch merges; already in
  ROADMAP.md's Out of Roadmap Scope and STATE.md blockers.

No scope creep occurred — discussion stayed inside the phase boundary throughout.
