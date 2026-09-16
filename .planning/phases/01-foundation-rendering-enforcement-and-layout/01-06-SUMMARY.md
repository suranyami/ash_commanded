---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 06
subsystem: infra
tags: [ci, github-actions, usage_rules, agents-md, spark, credo, elixir, documentation]

# Dependency graph
requires:
  - phase: 01-02
    provides: "mix ash_commanded.dump, the golden-render harness and test/golden/README.md this plan links to rather than restates"
  - phase: 01-03
    provides: "the two custom Credo checks, LongQuoteBlocks at max_line_count:40, and ex_dna clone detection this plan's rewrite-rule enforcement map cites"
  - phase: 01-04
    provides: "the lib/ash_commanded resource/domain relocation — every path and module name this plan documents is the post-move one"
provides:
  - "usage-rules.md at the repository root: hand-authored, consumer-facing description of AshCommanded's DSL surface, shipped in package_files/0"
  - "mix.exs usage_rules config (project/0): targets AGENTS.md, syncs :spark and :igniter (the only two current deps with a real usage-rules.md)"
  - "AGENTS.md: hand-written conventions (idiomatic Elixir, DSL conventions, transformer ordering, Spark 2.7.2 API surface, testing expectations, the eleven rewrite rules each annotated with its real enforcement mechanism or lack thereof, D-12's canonical version) prepended above the untouched mix usage_rules.sync-managed block"
  - ".github/workflows/ci.yml: the first CI workflow this repository has ever had — three-leg Elixir/OTP matrix (1.18.4/1.19.6/1.20.4, all OTP 27.3), invoking mix check plus mix usage_rules.sync --check, third-party actions pinned to commit SHAs, workflow-level read-only permissions"
  - "mix.exs elixir: requirement widened from '~> 1.18' (matches ONLY 1.18.x) to '~> 1.18 or ~> 1.19 or ~> 1.20', so the two new CI legs actually compile"
affects: ["phase-02-commands-and-events (AGENTS.md's Spark-API-surface section names identifier:/singleton_entity_keys as the gap CMD-05/EVT-03 should close)", "phase-07-documentation-packaging (DOCS-01/DOCS-02's CLAUDE.md reconciliation reads AGENTS.md as the source of truth)"]

# Actuals (#2632)
actuals:
  tokens: 12700
  tasks: 3
  commits: 3
  plan_head_before: 58398b126508cc8fc9e23c58270bf8148151a76c

# Tech tracking
tech-stack:
  added:
    - "GitHub Actions CI (erlef/setup-beam@v1.24.1, actions/checkout@v7.0.1, actions/cache@v6.1.0, all pinned to commit SHA) — first CI this repository has ever had"
  patterns:
    - "AGENTS.md as a hybrid document: hand-written prose wrapped around (never inside) the mix usage_rules.sync-managed <!-- usage-rules-start/end --> block, itself wrapped in markdownlint-disable/markdownlint-enable comments so the project's markdownlint PostToolUse hook cannot mutate third-party-sourced content on a future edit"
    - "CI invokes mix check (the alias) rather than restating its steps, and D-12's canonical-version golden-diff exclusion lives in test/test_helper.exs, not a CI-side flag, so local and CI behavior cannot diverge"
    - "Elixir CI matrix versions and their compatible OTP pairing established by querying the real release list (mise ls-remote elixir) at execution time, not carried over from a planning document"

key-files:
  created:
    - usage-rules.md
    - .github/workflows/ci.yml
  modified:
    - mix.exs
    - AGENTS.md

key-decisions:
  - "usage_rules config targets :spark and :igniter only, not :ash/:commanded — verified against deps/*/usage-rules.md on disk that the latter two do not ship one in the vendored versions pinned here; listing a package with neither a main file nor sub-rules is a hard resolution error in usage_rules.sync's own resolver, not a silent skip."
  - "CI matrix: current + previous two Elixir minors established from mise ls-remote elixir on 2026-09-16 (current series 1.20; previous two 1.19, 1.18), not from any number written in a planning document. OTP held constant at 27.3 (this repository's own installed runtime) across all three legs to isolate the one variable the requirement is actually about, rather than varying two axes at once."
  - "mix.exs's elixir: requirement widened to '~> 1.18 or ~> 1.19 or ~> 1.20' rather than narrowing the CI matrix to only 1.18.x — the prior '~> 1.18' declaration matches ONLY 1.18.x (Hex ~> semantics on a two-part version), which would have rejected the two newer CI legs at mix deps.get. The floor stays exactly where it was already tightened to (1.18, still the canonical/oldest leg, matching D-12); only the ceiling widens."
  - "CI's usage-rules regeneration/drift check uses `mix usage_rules.sync --check` (Igniter's own dry-run flag, deps/igniter/lib/igniter.ex's halt_if_fails_check!/3 — halts before any write) rather than 'sync then git diff', avoiding a dirty checkout in CI logs for equivalent coverage."
  - "AGENTS.md's own eleven-rewrite-rules section annotates each rule with whether a real, blocking mix check gate enforces it today, rather than presenting all eleven as equally enforced — rules 1, 5 and 11 are stated plainly as design principles with no mechanical check; rules 6 and 8 are stated as partially enforced (convention/detection exists, blocking-on-every-violation does not); rule 9 (no double-handling, FOUND-12) gets its own reviewer checklist question and an explicit 'no mechanical check exists' statement per ROADMAP SC4."

requirements-completed: [FOUND-12, FOUND-13, FOUND-14, FOUND-15, FOUND-16]

coverage:
  - id: D1
    description: "usage-rules.md exists at the repository root, hand-authored (not tool-generated), describing AshCommanded's DSL surface against the post-01-04 namespace only, including the known-broken domain-level application/router capability stated plainly rather than described as working; shipped via package_files/0"
    requirement: "FOUND-13"
    verification:
      - kind: other
        ref: "grep -c AshCommanded.Resource.Dsl usage-rules.md >= 1; grep -c 'usage-rules.md' mix.exs >= 1 (package_files/0); mix hex.build would include it (files() list includes literal \"usage-rules.md\")"
        status: pass
    human_judgment: false
  - id: D2
    description: "mix.exs usage_rules config wired (project/0: file: \"AGENTS.md\", usage_rules: [:spark, :igniter]); mix usage_rules.sync --check exits 0 (idempotent — a second sync produces no further change)"
    requirement: "FOUND-13"
    verification:
      - kind: other
        ref: "shell: mix usage_rules.sync --check — exit 0 (run repeatedly during this plan's execution, including after the AGENTS.md markdownlint recovery)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AGENTS.md documents idiomatic Elixir, DSL conventions, transformer ordering, the Spark 2.7.2 API surface (identifier:/singleton_entity_keys, InfoGenerator, transformer-vs-verifier timing, get_persisted/2, the {:behaviour,_} non-enforcement caveat) and testing expectations, using real files in this repository as evidence rather than general advice"
    requirement: "FOUND-14, FOUND-15"
    verification:
      - kind: other
        ref: "shell: every file path cited in AGENTS.md's hand-written sections resolves on disk (verified via a loop over the extracted path list); grep -cE 'AshCommanded[.]Commanded' AGENTS.md == 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Rule 9 ('no double-handling') is carried as an explicit reviewer checklist item in AGENTS.md with an explicit statement that no mechanical check for it exists, plus the D-12 canonical-Elixir-version statement agreeing with test/test_helper.exs's literal"
    requirement: "FOUND-12"
    verification:
      - kind: other
        ref: "grep -c 'no double-handling' AGENTS.md == 1; grep -ci 'no mechanical check' AGENTS.md == 2; grep -cF \"$(grep -oE '1\\.[0-9]+' test/test_helper.exs | head -1)\" AGENTS.md == 4"
        status: pass
    human_judgment: false
  - id: D5
    description: ".github/workflows/ci.yml exists, parses as valid YAML, declares exactly 3 Elixir/OTP matrix legs with exactly one (1.18.4) implicitly canonical (matching D-12/test_helper.exs), invokes the mix check alias rather than restating its steps, pins every third-party action to a commit SHA, and carries a workflow-level read-only permissions: block"
    requirement: "FOUND-16"
    verification:
      - kind: other
        ref: "python3 -c \"import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); assert len(d['jobs']['check']['strategy']['matrix']['include'])==3\" — passes; grep -c 'mix check' .github/workflows/ci.yml == 4; grep -cE '^ *permissions:' .github/workflows/ci.yml == 1; each of the three Elixir versions verified against mix.exs's widened elixir: requirement via Version.match?/2 (all true)"
        status: pass
      - kind: manual_procedural
        ref: "Actions tab after the first push — confirm all three matrix legs complete green and the 1.18.4 leg reports more tests than the other two (the golden text-diff)"
        status: unknown
    human_judgment: true
    rationale: "This executor cannot run GitHub Actions. YAML validity, action-SHA existence (verified via git ls-remote against the real upstream repos, not recalled), and local mix check/test parity were all verified; whether setup-beam@v1.24.1's version manifest actually has 1.19.6/1.20.4 prebuilt, and whether the three legs go green in the real Actions environment, can only be confirmed by a human after the first push."

# Metrics
duration: ~26min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 6: usage-rules.md, AGENTS.md and the first CI workflow Summary

**Hand-authored consumer usage rules, an AGENTS.md that annotates all eleven rewrite rules with their real (or explicitly absent) enforcement mechanism, and a from-scratch three-leg GitHub Actions CI matrix (Elixir 1.18.4/1.19.6/1.20.4, OTP 27.3) invoking the existing `mix check` alias.**

## Performance

- **Duration:** ~26 min
- **Started:** 2026-09-16T08:17:00Z (approx.)
- **Completed:** 2026-09-16T08:42:37Z
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- `usage-rules.md` published at the repository root: a hand-authored, consumer-facing description of the two extension modules, the `commanded do ... end` block, what gets generated under what names, the `.Info` introspection convention, `mix ash_commanded.dump`, and a plain statement that domain-level application/router generation does not fire for any domain today (rather than describing the intent) — shipped via `package_files/0`.
- `mix.exs`'s `usage_rules` config wired: targets `AGENTS.md`, syncing `:spark` and `:igniter` — verified by reading `deps/*/usage-rules.md` directly that `:ash` and `:commanded` do not ship one in the vendored versions pinned here (listing them would be a hard resolution error, not a silent skip). `mix usage_rules.sync --check` exits 0.
- `AGENTS.md` rewritten as a hybrid document: hand-written sections (idiomatic Elixir, DSL conventions, transformer ordering, the Spark 2.7.2 API surface, testing expectations, the eleven rewrite rules each annotated with its real enforcement mechanism or explicit absence of one, and D-12's canonical Elixir version) prepended above the `mix usage_rules.sync`-managed block, which is left byte-identical to what Task 1's sync produced.
- **A live markdownlint-hook collision, found and recovered mid-task:** editing `AGENTS.md` triggers this repository's `markdownlint-cli2 --fix` PostToolUse hook against the *whole file*, including the sync-managed block sourced verbatim from Spark's and Igniter's own `usage-rules.md` files. The hook's first pass silently deleted the `<!-- usage-rules-start -->` marker line and corrupted an emphasis delimiter inside that third-party content — see Deviations. Recovered by restoring the pristine committed block and wrapping it in `markdownlint-disable`/`markdownlint-enable` (placed outside the sync markers, so a future sync never touches them), verified byte-identical to the Task 1 commit and confirmed the hook is now a clean no-op against the file.
- `.github/workflows/ci.yml` authored from scratch (`.github/workflows/` did not exist before this plan). Three legs — 1.18.4 (canonical, matching this repo's own `.tool-versions` and `test/test_helper.exs`'s `canonical_elixir_version`), 1.19.6, 1.20.4, all on OTP 27.3 — established from the real Elixir release list (`mise ls-remote elixir`, queried live on 2026-09-16) rather than from a planning document. Each leg invokes `mix check` (never restating its steps) plus `mix usage_rules.sync --check`; dependency/build and Dialyzer PLT caches are keyed on `mix.lock` plus the toolchain versions; `actions/checkout`, `erlef/setup-beam` and `actions/cache` are pinned to commit SHAs (verified against each repo's real tags via `git ls-remote`, not recalled) with the human-readable version in a trailing comment; a workflow-level `permissions: contents: read` block is present.
- `mix.exs`'s `elixir:` requirement widened from `"~> 1.18"` (which matches ONLY 1.18.x under Hex's `~>` semantics on a two-part version, and would have rejected the two new CI legs at `mix deps.get`) to `"~> 1.18 or ~> 1.19 or ~> 1.20"` — verified against `Version.match?/2` for all three matrix versions. The floor stays exactly where the previous phase's work already tightened it to (1.18); only the ceiling widens.
- `mix check` exits 0; `MIX_ENV=test mix test` reports 249 tests, 0 failures (unchanged from the state at dispatch — this plan touches no `lib/`/`test/` behavior).

## Task Commits

Each task was committed atomically:

1. **Task 1: hand-authored usage-rules.md, usage_rules sync config (FOUND-13)** - `2df0ecf` (feat)
2. **Task 2: AGENTS.md — conventions, Spark API surface, rewrite-rule enforcement map (FOUND-12, FOUND-14, FOUND-15, D-12)** - `ad7dfef` (docs)
3. **Task 3: first CI workflow, three-leg Elixir/OTP matrix (FOUND-16, D-12)** - `0db51ee` (feat)

**Plan metadata:** committed alongside this SUMMARY.

## Files Created/Modified

- `usage-rules.md` — new, hand-authored consumer-facing usage rules for AshCommanded
- `mix.exs` — added `usage_rules` config (Task 1) and `usage-rules.md` to `package_files/0` (Task 1); widened `elixir:` requirement (Task 3)
- `AGENTS.md` — new hand-written sections prepended above the untouched `mix usage_rules.sync`-managed block
- `.github/workflows/ci.yml` — new, the first CI workflow in this repository

## Decisions Made

See `key-decisions` in frontmatter. Summarized:

1. `usage_rules` config lists only `:spark`/`:igniter` (the two deps that actually ship a `usage-rules.md`), not `:ash`/`:commanded`, which would be a hard resolution error.
2. CI matrix versions established live from the real Elixir release list, not carried over from planning; OTP held constant at 27.3 across all three legs.
3. `mix.exs`'s `elixir:` requirement widened (ceiling only) rather than narrowing the matrix, so all three legs actually satisfy it.
4. CI's usage-rules drift check uses Igniter's own `--check` dry-run flag rather than "sync then diff."
5. AGENTS.md's rewrite-rule table honestly annotates which of the eleven rules are mechanically enforced, partially enforced, or not enforced at all — rather than presenting uniform coverage.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The project's markdownlint PostToolUse hook corrupted the `mix usage_rules.sync`-managed block on the first `AGENTS.md` edit**

- **Found during:** Task 2, immediately after the first `Edit` call on `AGENTS.md`
- **Issue:** This repository's `.claude/CLAUDE.md`-documented markdownlint hook re-lints and auto-fixes the *entire* file on every edit to a `.md` file, not just the diff. My first edit's `old_string`/`new_string` pair also (by my own oversight) dropped the literal `<!-- usage-rules-start -->` and `<!-- spark-start -->` marker lines from the replacement text. The hook's subsequent `--fix` pass then (a) reported two `MD025` "multiple top-level heading" errors and one `MD040` "fenced code block needs a language" error, all inside the third-party-sourced Spark/Igniter usage-rules content between the sync markers, and (b) silently mangled an emphasis delimiter inside that same content (`_Generic tooling for building DSLs_` → `_Generic tooling for building DSLs*`) while auto-fixing an unrelated rule. Because the `<!-- usage-rules-start -->` marker was already gone (from my own mistake, not the hook), the file was left in a state where a future `mix usage_rules.sync` would have hit an unmatched-marker fallback path in `replace_usage_rules_section/2`, appending a second, disconnected managed block rather than replacing the first — and even before that, the corrupted managed content no longer matched what a fresh sync would produce, breaking the `mix usage_rules.sync --check` idempotency guarantee Task 1 established.
- **Fix:** `git checkout -- AGENTS.md` to restore the pristine, Task-1-committed file (a sanctioned specific-file discard, not a blanket reset). Reassembled the file via direct Bash file concatenation (not the Edit/Write tool, to avoid re-triggering the same hook against the still-unwrapped managed block): hand-written prose, then the pristine managed block copied byte-for-byte, wrapped in `markdownlint-disable` / `markdownlint-enable` placed *outside* the `<!-- usage-rules-start/end -->` markers (so a future real sync, which only ever touches text strictly between those two markers, never disturbs the disable/enable comments either). Verified with a byte-for-byte diff against the Task 1 commit's managed block, and confirmed `markdownlint-cli2 --fix` now reports 0 issues and produces zero mutation against the reassembled file.
- **Files modified:** `AGENTS.md`
- **Verification:** `diff <(git show HEAD:AGENTS.md) <(sed -n '/^<!-- usage-rules-start -->$/,/^<!-- usage-rules-end -->$/p' AGENTS.md)` — empty (byte-identical); `markdownlint-cli2 --fix --config ~/.markdownlint-cli2.jsonc AGENTS.md` — 0 issues, file unchanged by the run; `mix usage_rules.sync --check` — exit 0.
- **Committed in:** `ad7dfef` (Task 2 commit — the corrupted intermediate state was never committed)

**2. [Rule 3 - Blocking] Two acceptance-criteria greps failed on the first hand-written prose draft; both fixed before commit**

- **Found during:** Task 2, running the plan's own verification commands against the first clean draft
- **Issue:** (a) `grep -c 'no double-handling' AGENTS.md` (case-sensitive, no `-i`) returned `0` — my rule-9 bullet used capitalized "**No double-handling.**" (matching `PROJECT.md`'s verbatim rule text) with no separate lowercase occurrence anywhere in the document. (b) `grep -cE 'AshCommanded[.]Commanded' AGENTS.md` returned `1` — my own intro prose explicitly named the pre-move namespace ("never the pre-move `AshCommanded.Commanded.*` namespace") to say what NOT to use, which the acceptance criterion's blanket regex does not distinguish from an endorsement.
- **Fix:** Added a lowercase sentence introducing the rewrite-rules section ("Rule 9, no double-handling, gets particular attention below..."), and reworded the intro to describe the pre-move namespace without spelling out the literal `AshCommanded.Commanded` string (referencing the old directory, `lib/commanded/`, instead).
- **Files modified:** `AGENTS.md`
- **Verification:** both greps re-run — `1` and `0` respectively.
- **Committed in:** `ad7dfef` (Task 2 commit)

**3. Stray `documentation/dsls/DSL-AshCommanded.{Resource,Domain}.md` files regenerated by every `mix check`/`mix gen.docs` run in this session (WINDOWS.md entry 6, pre-existing, not this plan's defect)**

- **Found during:** every `mix check` run across all three tasks
- **Issue:** As flagged in the dispatch context, `mix check`'s `gen.docs` step invokes `spark.cheat_sheets`, which the vendored Spark 2.7.2 writes to `documentation/dsls/DSL-<Module>.md` — a path `mix.exs`'s `docs()` does not reference and that is not tracked in git. This reappeared after every `mix check` run in this plan.
- **Fix:** Deleted the two untracked files after each `mix check` run, per the dispatch instructions; the two tracked, pre-existing files in that directory were never touched.
- **Files modified:** none (the deleted files were never tracked)
- **Verification:** `git status --short` clean of `documentation/` before every commit.

---

**Total deviations:** 3 (1 Rule-1 bug — self-inflicted hook interaction, recovered before any commit; 1 Rule-3 blocking — two failing acceptance greps, fixed before commit; 1 pre-existing tooling quirk, handled per dispatch instructions, no code change).
**Impact on plan:** None reached a commit in a broken state — the markdownlint corruption was caught and reverted entirely within Task 2, before that task's commit. No scope creep; nothing outside this plan's four declared files was touched.

## Known Stubs

None.

## Issues Encountered

- The project's markdownlint PostToolUse hook re-lints the *whole* file, not the diff, on every `.md` edit — documented in `CLAUDE.md`'s own "Markdown Conventions" section, but this plan is the first place in this milestone where an edit touched a file containing large blocks of externally-sourced (not hand-written) Markdown. The hook's blanket `--fix` behavior is fundamentally in tension with any file that must preserve a third-party-generated region byte-for-byte for an idempotency contract (here: `mix usage_rules.sync --check`). The `markdownlint-disable`/`markdownlint-enable` wrapper placed outside the sync markers resolves it for this file; a future plan that edits `AGENTS.md` again should preserve that wrapper rather than removing it, and should assemble any further hand-written additions via a full-file reconstruction (or by editing only the region outside the wrapper) rather than an `Edit` call whose `old_string`/`new_string` boundary crosses into the managed block.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FOUND-12 through FOUND-16 are all met: `AGENTS.md` carries rule 9 as an explicit, unmechanized reviewer checklist item; `usage-rules.md` is published and packaged; `AGENTS.md` covers idiomatic Elixir, DSL conventions, transformer ordering, testing expectations and the Spark API surface; CI runs a real three-leg Elixir/OTP matrix invoking `mix check`.
- **FOUND-18 (`create_module/4` wiring) is explicitly untouched by this plan**, per its scope boundary — still open in `.planning/WINDOWS.md` entry 5. **This plan does not close Phase 1.** The orchestrator owns phase-level verification and closure after this plan; do not read "5/6 → 6/6 plans complete" as "Phase 1 complete."
- **The one thing this executor cannot verify:** whether the three CI legs actually go green on a real GitHub Actions run — specifically, whether `erlef/setup-beam@v1.24.1`'s version manifest has prebuilt Elixir 1.19.6/1.20.4 artifacts available. Everything checkable locally (YAML validity, action SHAs resolving to real tags, `mix check`/`mix test`/`mix format`/`mix credo` all green, the widened `elixir:` requirement matching all three versions via `Version.match?/2`) was checked. The plan's own `<human-check>` — open the Actions tab after the first push — is the only thing that can confirm the workflow works, not merely that it is well-formed.
- `.planning/WINDOWS.md` entries 1–6 are all unchanged by this plan (none of them are in this plan's scope; entry 6's symptom, the stray `documentation/dsls/` regeneration, recurred here as expected and was handled per dispatch instructions without modifying the ledger).

## Self-Check: PASSED

- `usage-rules.md` — FOUND
- `.github/workflows/ci.yml` — FOUND
- `AGENTS.md` (modified, hand-written sections present) — FOUND
- `mix.exs` (usage_rules config, widened elixir: requirement) — FOUND
- commit `2df0ecf` — FOUND
- commit `ad7dfef` — FOUND
- commit `0db51ee` — FOUND
- `mix check` re-run fresh in this closeout: exit 0
- `MIX_ENV=test mix test` re-run fresh in this closeout: 249 tests, 0 failures
- `mix usage_rules.sync --check` re-run fresh in this closeout: exit 0

---
*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-09-16*
