---
phase: "1"
slug: "foundation-rendering-enforcement-and-layout"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-15"
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `01-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) — `test/test_helper.exs` is exactly `ExUnit.start()`, no exclusions, no fixed seed |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix check` (format → `compile --warnings-as-errors` → credo → test → `compile_parity.sh` → dialyzer → `gen.docs`) |
| **Estimated runtime** | `mix test` ~2s today (176 tests, 1.1s measured 2026-09-15); `mix check` minutes, Dialyzer dominates |

**Baseline to preserve:** 176 tests, 0 failures, stable across 45+ consecutive full-suite runs, zero
mocking. Any drop below this is a regression, not a trade.

---

## Sampling Rate

- **After every task commit:** `mix test`
- **After every plan wave:** `mix check`
- **Before `/gsd-verify-work`:** `mix check` green on the canonical Elixir version (golden text diff
  runs) AND on every other matrix leg (text diff skipped, size and lint gates still run) — per D-12
- **Max feedback latency:** ~2 seconds for `mix test`

---

## Per-Requirement Verification Map

Task IDs are assigned when plans are written; this seeds the requirement→test mapping the planner
must satisfy.

| Requirement | Behavior | Test Type | Automated Command | File Exists |
|-------------|----------|-----------|-------------------|-------------|
| FOUND-01, 02, 05 | `mix ash_commanded.dump` renders pre-`Module.create/3` AST; `--write` updates golden | integration (task invoked from a test) | `mix test test/ash_commanded/dump_task_test.exs` | ❌ W0 |
| FOUND-03 | `--beam` renders post-compile `debug_info` | integration | same file, tagged case | ❌ W0 |
| FOUND-04 | Golden text diffed in CI, canonical version only | integration, tagged `:canonical_version_only` | `mix test test/ash_commanded/golden_render_test.exs` | ❌ W0 |
| FOUND-06 | Clause over ~10 lines fails | unit, every CI leg | `mix test test/ash_commanded/golden_budget_test.exs` | ❌ W0 |
| FOUND-07 | `quote` block over 40 lines fails | static analysis | `mix credo` — `LongQuoteBlocks` already enabled at `.credo.exs:128`; config change only | ✅ config |
| FOUND-08 | Compile-time-known values reassembled at runtime fails | unit, every CI leg | `mix test test/ash_commanded/golden_budget_test.exs` | ❌ W0 |
| FOUND-09 | `Code.string_to_quoted!`/`eval_string` in transformers fails | custom Credo check + `Credo.Test.Case` | `mix credo`; `mix test test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs` | ❌ W0 |
| FOUND-10 | Module-name surgery fails | custom Credo check + `Credo.Test.Case` | `mix credo`; `mix test test/ash_commanded/credo_checks/no_module_name_surgery_test.exs` | ❌ W0 |
| FOUND-11 | Structural duplicate detection beyond Credo's built-in | static analysis (`ex_dna`) | `mix credo` | ❌ dep + config |
| FOUND-12 | Rule 9 recorded as a reviewer checklist item with an explicit "no mechanical check exists" statement | manual — see below | grep `AGENTS.md` for the item | ❌ W0 |
| FOUND-13, 14, 15 | `usage_rules` synced; AGENTS.md documents idiom, conventions, ordering, testing, Spark surface | manual read + sync command | `mix usage_rules.sync` (verify exact verb); `AGENTS.md` exists | ❌ W0 |
| FOUND-16 | CI green on current Elixir/OTP plus previous two minors | CI config | `.github/workflows/ci.yml` green on 3 legs | ❌ W0 — **does not exist at all** |
| FOUND-17 | `lib/` has sibling `resource/` and `domain/` trees, each with `transformers/`, `verifiers/`, `info.ex` | integration — behaviour-neutral move | `mix test`, `./scripts/compile_parity.sh`, pre/post-move golden diff | partial — `compile_parity.sh` exists |
| FOUND-18 | Shared helper sets explicit `file:`/`line:`; a deliberate error in generated code reports an openable location | unit | `mix test test/commanded/transformers/base_transformer_test.exs` | ✅ **exists** — extend, do not recreate |
| D-02 (supports FOUND-06..11) | Every gate disable cites a live, incomplete phase | unit | `mix test test/ash_commanded/disable_phase_citation_test.exs` | ❌ W0 |
| ROADMAP SC3 | Five seeded violations each fail with a message naming file and rule, and go green when removed | unit (meta-test over fixtures) | `mix test test/ash_commanded/seeded_violations_test.exs` | ❌ W0 |

---

## Wave 0 Requirements

- [ ] `test/ash_commanded/dump_task_test.exs` — FOUND-01/02/03/05
- [ ] `test/ash_commanded/golden_render_test.exs` — FOUND-04, tagged `:canonical_version_only`
- [ ] `test/ash_commanded/golden_budget_test.exs` — FOUND-06/08, over `test/golden/**/*.golden`
- [ ] `test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs` — FOUND-09
- [ ] `test/ash_commanded/credo_checks/no_module_name_surgery_test.exs` — FOUND-10
- [ ] `test/ash_commanded/seeded_violations_test.exs` — ROADMAP SC3
- [ ] `test/ash_commanded/disable_phase_citation_test.exs` — D-02
- [ ] `priv/seeded_violations/*.ex` — five fixtures, one per gate; inputs to the meta-test, not tests
- [ ] `.github/workflows/ci.yml` — FOUND-16; no CI exists today
- [ ] `ex_dna` added to `mix.exs` and wired into `.credo.exs` — FOUND-11

**Blocking decision before FOUND-10's check can be written:** `Module.split`/`Module.concat` appear
30 times across 13 files, including `base_transformer.ex:22,26,41` inside `get_module_prefix/1` — the
seam FOUND-18 and D-06 attach to. The check will fire on the module this phase builds. The plan must
either rewrite that helper to derive from `Transformer.get_persisted/2`, or suppress it under
D-01/D-02 naming the phase that removes the suppression. It must also separate three lookalike uses:
deriving a module atom to reference (the defect), building a display string
(`logging_middleware.ex:37,57,75`), and naming a process (`generate_commanded_application.ex:130,135`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A human has read a rendered module and approved its conciseness | Method step 4; gates every component phase from Phase 2 on | The whole point is human judgement about readability — a passing size check is necessary, not sufficient | Run `mix ash_commanded.dump <fixture>`, read the output, record approval in the phase verification record, commit the golden |
| Rule 9, "no double-handling", is honoured | FOUND-12 | Research confirmed **no tool exists** — it is a data-flow-ownership question no static analyser reasons about | Reviewer checklist item in `AGENTS.md`, applied at code review |
| Generated-code errors report an openable `file:`/`line:` | FOUND-18 | The automated half asserts metadata is set; that it is *useful* needs a human opening it | Introduce a deliberate error in a fixture, compile, click the reported location |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for `mix test`
- [ ] Baseline preserved: 176 tests, 0 failures
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
