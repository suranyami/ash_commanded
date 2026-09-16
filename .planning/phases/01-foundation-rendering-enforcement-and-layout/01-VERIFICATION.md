---
phase: 01-foundation-rendering-enforcement-and-layout
verified: 2026-09-16T21:10:00Z
status: gaps_found
score: 18/20 must-haves verified
covered_files: [".credo.exs", ".dialyzer_ignore.exs", ".github/workflows/ci.yml", ".planning/REQUIREMENTS.md", ".planning/ROADMAP.md", ".planning/WINDOWS.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-01-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-01-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-02-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-02-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-03-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-03-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-04-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-04-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-05-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-05-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-06-PLAN.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-06-SUMMARY.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-CLONE-REPORT.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-CONTEXT.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-REVIEW.md", ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-VALIDATION.md", "AGENTS.md", "lib/ash_commanded/credo_checks/exemption.ex", "lib/ash_commanded/credo_checks/no_module_name_surgery.ex", "lib/ash_commanded/credo_checks/no_runtime_string_to_ast.ex", "lib/ash_commanded/domain/dsl.ex", "lib/ash_commanded/domain/info.ex", "lib/ash_commanded/dump/golden.ex", "lib/ash_commanded/dump/lint.ex", "lib/ash_commanded/dump/render.ex", "lib/ash_commanded/resource/dsl.ex", "lib/ash_commanded/resource/info.ex", "lib/ash_commanded/resource/transformers/base_transformer.ex", "lib/mix/tasks/ash_commanded.dump.ex", "mix.exs", "scripts/compile_parity.sh", "test/ash_commanded/credo_checks/no_module_name_surgery_test.exs", "test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs", "test/ash_commanded/disable_phase_citation_test.exs", "test/ash_commanded/dump_task_test.exs", "test/ash_commanded/golden_budget_test.exs", "test/ash_commanded/golden_render_test.exs", "test/ash_commanded/seeded_violations_test.exs", "test/ash_commanded/transformers/base_transformer_test.exs", "usage-rules.md"]
covered_digest: "v1:sha256:f0d9970d32741166e675714f7b2cbdb3b4b59f1367cac046fc08dacb9a50ff6c"
behavior_unverified: 1
overrides_applied: 0
gaps:
  - truth: "A shared module-creation helper sets explicit file:/line: metadata so a deliberate error inside generated code reports a file and line naming the DSL declaration's own source (FOUND-18; ROADMAP Phase 1 SC5's fifth clause)."
    status: failed
    reason: >
      BaseTransformer.create_module/4, which accepts an explicit [:file, :line] location, exists
      and is unit-tested in isolation (test/ash_commanded/transformers/base_transformer_test.exs,
      three passing tests including one asserting a compile error names the supplied location).
      But independently re-grepping every real create_module call site in lib/ (not trusting
      01-01-SUMMARY.md's or WINDOWS.md's own account) confirms all nine module-creating
      transformers still call the 3-arg create_module(module, ast, __ENV__) form, which falls
      back to Macro.Env.location(env) — the transformer's own file, not the DSL declaration's.
      Plan 01-01 Task 2 explicitly forbade touching the nine call sites, so this is scope-correct
      execution against every individual plan, but it means the requirement's actual outcome —
      "generated-code errors point somewhere useful" — is not demonstrable anywhere in the
      library today. REQUIREMENTS.md already carries FOUND-18 as "[ ]" / "Gaps Found" (reverted
      from a prior, incorrect "Complete" mark per commit 3b3bb56) and WINDOWS.md entry 5 records
      the same fact — this verification concurs with, and does not relax, that self-correction.
    artifacts:
      - path: "lib/ash_commanded/resource/transformers/base_transformer.ex"
        issue: "create_module/4 (explicit location) exists and is tested, but is dead code from every real caller's perspective — nothing in lib/ invokes it."
      - path: "lib/ash_commanded/resource/transformers/generate_command_modules.ex"
        issue: "create_module(...) call at line 81 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_event_modules.ex"
        issue: "create_module(...) call at line 79 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_projection_modules.ex"
        issue: "create_module(...) call at line 78 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_projector_modules.ex"
        issue: "create_module(...) call at line 148 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_event_handler_modules.ex"
        issue: "create_module(...) call at line 125 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_aggregate_module.ex"
        issue: "create_module(...) call at line 174 uses the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/resource/transformers/generate_main_router_module.ex"
        issue: "two create_module(...) calls (lines 148, 152) use the 3-arg form; no explicit location passed."
      - path: "lib/ash_commanded/domain/transformers/generate_commanded_application.ex"
        issue: "create_module(...) call at line 95 uses the 3-arg form; no explicit location passed."
    missing:
      - "Wire at least the transformers rewritten by upcoming phases (or all nine, if the fix is generic) to pass file: Spark.Dsl.Transformer.get_persisted(dsl_state, :file) — and a line — through create_module/4, per base_transformer.ex's own moduledoc guidance."
      - "A test demonstrating end-to-end that a deliberate compile error inside a real generated module (not the isolated unit test's synthetic AST) reports the DSL-declaring resource/domain file, not the transformer's file."
      - "A gap-closure plan is already referenced as planned per this phase's own briefing; this finding confirms it is still needed and gives it the current call-site list to fix."
behavior_unverified_items:
  - truth: "CI runs the suite green on the current Elixir/OTP release plus the previous two minors, invoking the real `mix check` alias and gating the golden text-diff to the canonical leg (FOUND-16, D-12; also the CI half of FOUND-04's 'diffed in CI' claim)."
    test: "Push this branch (or open a PR against it) and observe all three legs of .github/workflows/ci.yml's matrix (Elixir 1.18.4/1.19.6/1.20.4, OTP 27.3) complete `mix check` and `mix usage_rules.sync --check` with exit 0."
    expected: "All three matrix legs report green; the canonical leg (1.18.4) additionally exercises the golden text-diff (test/ash_commanded/golden_render_test.exs); the two non-canonical legs skip only that one tagged test and still run everything else, per test/test_helper.exs's version-gated exclusion."
    why_human: >
      GitHub Actions execution is an external system this verifier cannot invoke from the local
      sandbox. `gh run list` returns zero rows on both configured remotes (origin =
      suranyami/ash_commanded, accountex-org/ash_commanded upstream), and `git ls-remote origin
      fix-application-generation` / `git ls-remote accountex-org fix-application-generation` both
      return nothing — the branch carrying this work is not currently pushed anywhere GitHub can
      run it against. The workflow file itself is well-authored and internally consistent (it
      invokes `mix check` rather than restating steps, its canonical-version leg matches
      `test/test_helper.exs`'s literal and `.tool-versions`, and its permissions/caching are
      sound), but its actual execution and outcome have never been observed by anyone, which is
      exactly the "green because it ran nothing" defect class this phase exists to guard against
      everywhere else. Presence and internal consistency are confirmed; live execution is not.
---

# Phase 1: Foundation — Rendering, Enforcement and Layout Verification Report

**Phase Goal:** A developer can see exactly what AshCommanded generates, and the build rejects
generated output that breaks the rewrite rules — so every later phase has something real to
approve against.
**Verified:** 2026-09-16
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | -------- | ---------- |
| 1 | `mix ash_commanded.dump <Module>` prints formatted Elixir source rendered from the pre-`Module.create/3` AST by default (FOUND-01, FOUND-02) | ✓ VERIFIED | Manually ran `mix ash_commanded.dump AshCommanded.TestSupport.Parity.Widget --only ...CreateWidget`; `test/ash_commanded/dump_task_test.exs` (`--only narrows output...`) passes and asserts real `defmodule` bodies. Bare invocation against a fixture whose golden already matches prints nothing by design (D-07: "diffs... prints full render when one does not exist") — confirmed by reading `diff_golden/2`'s `old_body == body -> :ok` branch, not a defect. |
| 2 | `--beam` renders the post-compile `debug_info` view and visibly differs from the default view where macros expanded (FOUND-03) | ✓ VERIFIED | `dump_task_test.exs`: `"--beam prints source recovered from debug_info, and it differs from the default view..."` asserts `beam_output =~ "def child_spec("` and `beam_output != default_output`; test passes. |
| 3 | A bare invocation diffs against the committed golden locally, blocking `mix test`/`mix check` on an unreviewed change; `--write` regenerates in one documented command and refuses silent budget growth (FOUND-04 local half, FOUND-05, D-04, D-07, D-11) | ✓ VERIFIED | `test/golden/README.md` documents the single `--write` command; `dump_task_test.exs`'s "diff and --write" describe block (refusal-naming-the-budget test included) passes; `golden_render_test.exs` runs as part of the 259-test suite and is what actually blocks locally. |
| 4 | CI actually executes and enforces the above — the "in CI" half of FOUND-04, and FOUND-16's three-leg matrix — on the current Elixir/OTP release plus the previous two minors (FOUND-04 CI half, FOUND-16, D-12) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `.github/workflows/ci.yml` exists, is well-formed, and is internally consistent (invokes `mix check`, matches `test/test_helper.exs`'s canonical-version literal). But it has never been observed to run: `gh run list` returns 0 rows on both remotes; the branch is not currently pushed anywhere. See Human Verification. |
| 5 | A rendered clause over ~10 lines fails the build, naming the golden and the measured/declared numbers (FOUND-06) | ✓ VERIFIED | `test/ash_commanded/golden_budget_test.exs` (part of the 259-test suite) + `01-GATE-EVIDENCE.md`'s captured real `mix check` failure/recovery transcript for this exact gate; `seeded_violations_test.exs`'s permanent regression test (`FOUND-06` describe block) passes. |
| 6 | A `quote` block over 40 lines fails the build, naming the file (FOUND-07) | ✓ VERIFIED | `.credo.exs`'s `Credo.Check.Refactor.LongQuoteBlocks, [max_line_count: 40]`; `01-GATE-EVIDENCE.md`'s captured transcript; `seeded_violations_test.exs`'s regression test passes; independently re-ran `mix credo` — exit 0, 71 checks, 0 issues on the current tree. |
| 7 | Compile-time-known values reassembled at runtime in rendered output fail the build, naming the golden and line (FOUND-08) | ✓ VERIFIED | `AshCommanded.Dump.Lint` wired into `golden_budget_test.exs`; `01-GATE-EVIDENCE.md`'s transcript names line 3 of the seeded golden; regression test passes. |
| 8 | AST built from an interpolated/reparsed string fails the build, naming the file and function (FOUND-09) | ✓ VERIFIED | `AshCommanded.CredoChecks.NoRuntimeStringToAst`, required and enabled in `.credo.exs`; `01-GATE-EVIDENCE.md` transcript; regression test in `seeded_violations_test.exs` passes; re-ran `mix credo` clean. |
| 9 | A module name built by `Module.split`/`Module.concat` surgery fails the build, everywhere except one named, documented exemption (FOUND-10) | ✓ VERIFIED | `AshCommanded.CredoChecks.NoModuleNameSurgery` + `AshCommanded.CredoChecks.Exemption`; the one exemption is `base_transformer.ex`'s `get_module_prefix/1`, marked with `# ash_commanded:namespace-derivation` and explained in its own moduledoc; `01-GATE-EVIDENCE.md` transcript; regression test passes; `mix credo` clean on the real tree. |
| 10 | Structural clone detection runs across `lib/` and a committed report names a clone pair Credo's built-in duplicate check misses (FOUND-11, ROADMAP SC4) | ✓ VERIFIED | `01-CLONE-REPORT.md` shows real `mix ex_dna lib/` output vs. a temporarily-re-enabled `Credo.Check.Design.DuplicatedCode` run, with a Type-II (renamed-variable) clone pair (`generate_event_handler_modules.ex` / `generate_projector_modules.ex`) found only by `ExDNA.Credo`. `.credo.exs` carries both the plugin registration and the required explicit `enabled:` entry with a comment explaining why both are needed (verified against the plugin's real merge behaviour, not assumed). |
| 11 | `AGENTS.md` carries Rule 9 ("no double-handling") as an explicit reviewer checklist item with an explicit statement that no mechanical check exists (FOUND-12, ROADMAP SC4) | ✓ VERIFIED | Read `AGENTS.md`'s "The eleven rewrite rules" §9: "**No mechanical check exists for this, and none is planned**", followed by the reviewer checklist question. |
| 12 | `usage_rules` is a dev dependency and the library publishes and packages its own consumer-facing usage rules (FOUND-13) | ✓ VERIFIED | `mix.exs:104` (`{:usage_rules, "~> 1.2", only: [:dev]}`), `usage-rules.md` (172 lines, hand-written), `package_files/0` includes `usage-rules.md` and excludes `lib/ash_commanded/credo_checks/`; `mix hex.build` output confirmed both; `mix usage_rules.sync --check` re-run — exit 0. |
| 13 | `AGENTS.md` documents idiomatic Elixir, DSL conventions, transformer ordering, testing expectations and the Spark API surface, with `core` as the worked reference (FOUND-14, FOUND-15) | ✓ VERIFIED | Read all named sections directly (`## Idiomatic Elixir...`, `## DSL conventions`, `## Transformer ordering`, `## The Spark API surface (FOUND-15)`, `## Testing expectations`); `core` referenced by name in context. |
| 14 | `lib/` has sibling `resource/` and `domain/` trees, each with its own `transformers/`, `verifiers/` and `info.ex` (FOUND-17) | ✓ VERIFIED | `find lib -maxdepth 3 -type d` shows `lib/ash_commanded/resource/{transformers,verifiers,sections}` and `lib/ash_commanded/domain/transformers`; `resource/info.ex` and `domain/info.ex` both exist and use `Spark.InfoGenerator`. |
| 15 | A shared module-creation helper sets explicit `file:`/`line:` metadata so generated-code errors point somewhere useful (FOUND-18) | ✗ FAILED | See Gaps. `create_module/4` exists and is unit-tested in isolation but is called by zero of the nine real transformer call sites — independently confirmed by `grep -rn "create_module(" lib/`. |
| 16 | Five deliberately-seeded violations each fail `mix check` naming the file and rule, and removing each turns the build green again (ROADMAP SC3) | ✓ VERIFIED | `01-GATE-EVIDENCE.md` — real, verbatim `mix check` transcripts for all five, captured this session per the document's own account, plus recovery transcripts. `test/ash_commanded/seeded_violations_test.exs` (permanent regression half) — re-ran directly: 9 tests, 0 failures. |
| 17 | Every gate disable and staged-golden marker cites a live, incomplete roadmap phase; the pre-existing 15 disables (previously citing the archived roadmap) are re-pointed (D-01, D-02) | ✓ VERIFIED | `test/ash_commanded/disable_phase_citation_test.exs` re-ran directly: 9 tests, 0 failures — including the two "real repository" tests that walk `lib/` and `test/golden/` live. Spot-checked several real disables (`error.ex`, `command_action_mapper.ex`, `generate_aggregate_module.ex`) — all cite phases 2/4/5/6, all "Not started" in the current `ROADMAP.md` Progress table. |
| 18 | Re-rendering every committed golden after the `lib/commanded/` → `lib/ash_commanded/` move produces no diff, or a diff whose every line is a module-name literal (D-14, FOUND-04) | ✓ VERIFIED | `test/ash_commanded/golden_render_test.exs` (part of the 259-test suite that passes at HEAD) is the live version of exactly this check — it diffs the current, post-move tree's fresh renders against the committed goldens (which are already named `AshCommanded.TestSupport.Parity.*`) on every run; a real behaviour change would fail it now, not just at move-time. |
| 19 | The DSL block is still written `commanded do ... end` after the move (D-15) | ✓ VERIFIED | `grep -n "commanded do" test/support/parity/parity_widget.ex` → line 16. |
| 20 | `mix check` is green and the suite is at or above the 176-test baseline (Standing Constraint) | ✓ VERIFIED | Independently re-ran: `mix compile --warnings-as-errors` exit 0; `MIX_ENV=test mix test` → 259 tests, 0 failures; `mix credo` → 71 checks, 0 issues, exit 0. (Full `mix check` including Dialyzer/`gen.docs` not re-run in full here since `compile`+`credo`+`test` are the parts this phase's own gates touch and were independently reproduced; the orchestrator's measured-state block already reports the same numbers plus a Dialyzer/`gen.docs` pass, and nothing found in this verification contradicts it.) |

**Score:** 18/20 truths verified (1 present, behavior-unverified; 1 failed)

### Required Artifacts

| Artifact | Expected | Status | Details |
| ---------- | ---------- | -------- | --------- |
| `lib/mix/tasks/ash_commanded.dump.ex` | The renderer mix task, both views, diff/write/refuse | ✓ VERIFIED | 381 lines; exercised directly and via `dump_task_test.exs` |
| `lib/ash_commanded/dump/golden.ex` | Golden header parse/measure, budget ratchet | ✓ VERIFIED | Backs `golden_budget_test.exs` and the mix task's `--write` path identically (shared code, not two copies) |
| `lib/ash_commanded/dump/lint.ex` | Runtime-reassembly lint (FOUND-08) | ✓ VERIFIED | Confirmed via seeded fixture + gate evidence |
| `lib/ash_commanded/dump/render.ex` | AST → formatted source rendering | ✓ VERIFIED | Used by both dump-task views |
| `lib/ash_commanded/resource/transformers/base_transformer.ex` | AST-capture seam, `create_module/3,4` | ⚠️ ORPHANED (partial) | `create_module/3` (capture hook) is fully wired and load-bearing; `create_module/4` (FOUND-18's explicit location) is unit-tested but has zero real callers — see Gaps |
| `lib/ash_commanded/credo_checks/{no_runtime_string_to_ast,no_module_name_surgery,exemption}.ex` | FOUND-09/10 gates + the one named exemption mechanism | ✓ VERIFIED | Required via `.credo.exs`, enabled, proven against `mix credo` and the seeded fixtures |
| `lib/ash_commanded/resource/{dsl,info}.ex`, `lib/ash_commanded/domain/{dsl,info}.ex` | FOUND-17 namespace + `.Info` convention | ✓ VERIFIED | Present, compiling, `Spark.InfoGenerator`-backed |
| `.credo.exs` | Custom checks required+enabled, `ex_dna` plugin, `LongQuoteBlocks` at 40 | ✓ VERIFIED | Read directly; matches every gate claimed |
| `AGENTS.md` | FOUND-12/14/15 content | ✓ VERIFIED | 710 lines, all required sections present and checkable |
| `usage-rules.md` | FOUND-13 hand-written consumer rules | ✓ VERIFIED | 172 lines, packaged |
| `.github/workflows/ci.yml` | FOUND-16 three-leg matrix invoking `mix check` | ⚠️ PRESENT, unexecuted | See Observable Truth #4 / Human Verification |
| `.planning/phases/.../01-CLONE-REPORT.md` | FOUND-11 comparison report | ✓ VERIFIED | Contains real, reproducible tool output and an honest methodology section |
| `.planning/phases/.../01-GATE-EVIDENCE.md` | ROADMAP SC3 literal evidence | ✓ VERIFIED | Real verbatim `mix check` transcripts for all five violations, both directions |
| `test/ash_commanded/seeded_violations_test.exs`, `test/ash_commanded/disable_phase_citation_test.exs` | Permanent regression coverage | ✓ VERIFIED | Both re-ran directly, 0 failures |

### Key Link Verification

| From | To | Via | Status | Details |
| ------ | ---- | ---- | -------- | --------- |
| `mix ash_commanded.dump` | `BaseTransformer.create_module/3`'s capture hook | `:ash_commanded_dump_capture` ETS table, `Application.get_env(:ash_commanded, :capture_ast?)` | ✓ WIRED | Confirmed by reading the capture/restore cycle and by the passing `dump_task_test.exs` suite exercising it live |
| `--write` refusal | `golden_budget_test.exs` | shared `AshCommanded.Dump.Golden` module | ✓ WIRED | Both explicitly use the same header-parsing/measuring code (confirmed by reading `golden_budget_test.exs`'s own moduledoc and `mix.exs`-level module reuse) |
| `.credo.exs`'s custom checks | `mix credo`/`mix check` | `requires:` glob + `checks: enabled:` entries | ✓ WIRED | Re-ran `mix credo` directly: 0 issues, 71 checks including both custom checks and `ExDNA.Credo` |
| `.github/workflows/ci.yml` | `mix check` alias | `run: mix check` (no restated steps) | ⚠️ WIRED, unexecuted | The link is correctly authored (verified by reading both files) but has never fired in a real Actions run — see gap above |
| Nine transformer call sites | `BaseTransformer.create_module/4`'s explicit-location arity | (none — not called) | ✗ NOT_WIRED | Confirmed by `grep`; this is FOUND-18's gap |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
| --- | --- | --- | --- |
| FOUND-01 | `dump` renders generated code as formatted Elixir | ✓ SATISFIED | Truth #1 |
| FOUND-02 | Defaults to pre-`Module.create/3` AST | ✓ SATISFIED | Truth #1 |
| FOUND-03 | `--beam` post-compile view | ✓ SATISFIED | Truth #2 |
| FOUND-04 | Goldens committed and diffed in CI, failing on unreviewed change | ⚠️ PARTIAL | Local half (Truth #3) satisfied; CI half (Truth #4) unverified — never executed |
| FOUND-05 | One documented regeneration command | ✓ SATISFIED | Truth #3, `test/golden/README.md` |
| FOUND-06 | Clause >~10 lines fails build | ✓ SATISFIED | Truth #5 |
| FOUND-07 | `quote` block >40 lines fails build | ✓ SATISFIED | Truth #6 |
| FOUND-08 | Runtime reassembly of compile-time values fails build | ✓ SATISFIED | Truth #7 |
| FOUND-09 | `Code.string_to_quoted!`/`eval_string` in transformer fails build | ✓ SATISFIED | Truth #8 |
| FOUND-10 | Module-name surgery fails build (with one named exemption) | ✓ SATISFIED | Truth #9 |
| FOUND-11 | Structural clone detection beyond Credo's built-in check | ✓ SATISFIED | Truth #10 |
| FOUND-12 | Rule 9 explicit checklist item, explicit no-check statement | ✓ SATISFIED | Truth #11 |
| FOUND-13 | `usage_rules` dev dep + published usage rules | ✓ SATISFIED | Truth #12 |
| FOUND-14 | `AGENTS.md`: idiomatic Elixir, DSL conventions, transformer ordering, testing, `core` reference | ✓ SATISFIED | Truth #13 |
| FOUND-15 | `AGENTS.md`: Spark API surface | ✓ SATISFIED | Truth #13 |
| FOUND-16 | CI on current + previous two minors | ⚠️ UNVERIFIED | Truth #4 — file present and correct, execution never observed |
| FOUND-17 | `lib/` reorganised into `resource/`+`domain/` trees | ✓ SATISFIED | Truth #14 |
| FOUND-18 | Shared module-creation helper sets explicit `file:`/`line:` metadata | ✗ BLOCKED | Truth #15 / Gaps — matches REQUIREMENTS.md's own already-corrected "Gaps Found" status |

No orphaned requirements: all 18 FOUND-01..18 IDs appear in at least one of the six plans' `requirements:` frontmatter and are accounted for above.

### Anti-Patterns Found

None. Scanned all files this phase authored or substantially modified (the `covered_files` implementation set) for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, empty stub returns, and hardcoded-empty props. The only match was `.credo.exs:107`'s `Credo.Check.Design.TagFIXME` — a Credo check *name*, not a debt marker. No debt-marker gate violations.

### Deliberate Decisions Not Reported as Gaps

Per this verification's briefing, the following are confirmed present as described and are not
findings:

1. `priv/seeded_violations/*.ex` — confirmed off `elixirc_paths` and off Credo's `included:` globs; deliberately uncompiled/unlinted fixtures, working as designed.
2. `Design.AliasUsage` disabled rather than fixing 72 call sites — confirmed in `.credo.exs`'s `disabled:` list with an honest comment; a real strictness reduction, already tracked as WINDOWS.md #3, not hidden.
3. 17 `# gsd-disable-until-phase:`-style citations in `lib/` (confirmed: `# gsd-disable-until-phase:` is the exact marker `disable_phase_citation_test.exs` parses), enforced live by the passing citation test.
4. `grep -c 'DuplicatedCode' .credo.exs` == 2, not 1 — confirmed unsatisfiable as literally stated (Credo's own template comment at line ~87 predates this phase); tracked as WINDOWS.md #4.
5. 01-03 Task 1's single-commit RED→GREEN reconstruction — not independently re-auditable from the commit graph alone; taken on the SUMMARY's own account per the briefing.
6. Generator-module debt under `resource/transformers/` slated for phases 2–6 — confirmed present (e.g. `generate_aggregate_module.ex`'s multiple phase-4-cited disables) and correctly not this phase's problem.

### Code Review Findings (01-REVIEW.md) Cross-Check

- CR-01 (`Golden.measure_clause_spans/1` KeyError on one-line `do:` clauses) — commits `a3a5c64`
  (RED) / `3b015a1` (GREEN) confirmed in `git log`; re-ran `golden_budget_test.exs` directly as
  part of the 259-test pass — green.
- CR-02 (`Exemption.marker_line?/1` prose-mention false-exemption, vacuous guard test) —
  commits `0d8999b` (RED) / `e720414` (GREEN) confirmed in `git log`; `seeded_violations_test.exs`
  re-ran directly — green, including the module-name-surgery fixture's own comment warning
  against pasting the marker's literal text.
- CR-03 (`parameter_transformer.ex:292`'s `String.to_atom/1` on caller-supplied params) —
  confirmed pre-existing (not touched by any of this phase's six plans' `files_modified` lists)
  and correctly deferred, not this phase's scope.
- WR-01 (`collect_parameter_transforms.ex`/`collect_parameter_validations.ex` ignoring DSL
  contents) — confirmed these two files are pre-existing generator code, not touched by any
  phase-1 plan's `files_modified`, and not mapped to any FOUND-01..18 requirement. Correctly
  out of this phase's scope; flagging for whoever owns the command/projection rewrite (phases 2/5)
  since it does bear on "the DSL being honoured" more broadly than this phase's charter.

## Gaps Summary

One must-have fails outright: **FOUND-18**. The shared `create_module/4` helper that would let a
deliberate error inside generated code report the DSL declaration's file — not the transformer's
— exists and is unit-tested in complete isolation, but is wired into none of the nine real
transformer call sites. This was scope-correct for every individual plan (01-01 Task 2 explicitly
forbade touching the call sites), which is exactly why it survives to phase level: no single plan
owned closing the loop, so nobody did. REQUIREMENTS.md and WINDOWS.md already carry this
accurately (self-corrected from an earlier, wrong "Complete" mark), and this verification
independently reproduces the same conclusion via a live `grep` rather than trusting either
document's account.

One must-have is present but behaviourally unverifiable in this sandbox: **CI actually running**.
The workflow file is well-built and internally consistent, but it has executed zero times on any
reachable remote. This is not a code defect — it may well pass cleanly the first time it runs —
but per this phase's own stated purpose (turning aspirational gates into things that actually
fire), "the YAML exists and reads correctly" is not equivalent to "CI enforces this," and the
distinction matters enough here to record explicitly rather than assume away.

Everything else — the renderer's two views, the golden corpus and its ratchet, all five rewrite-
rule gates (with both a one-time literal transcript and a permanent regression test each), the
clone-detection comparison, the namespace move's behavioural-neutrality proof, and the
documentation/packaging artifacts — was independently re-derived from the live codebase (not
taken from SUMMARY.md prose) and holds up.

---

*Verified: 2026-09-16*
*Verifier: Claude (gsd-verifier)*
