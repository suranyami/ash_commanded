---
phase: "1"
slug: "build-integrity"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-12"
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property               | Value                                                                                                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Framework**          | ExUnit (bundled with Elixir; no version pin beyond the Elixir version itself)                                                                                   |
| **Config file**        | `mix.exs` (`test_coverage`, `preferred_cli_env` — none exist yet; added by D-18)                                                                                |
| **Quick run command**  | `mix test test/commanded/command_action_mapper_test.exs` (or any single touched file)                                                                           |
| **Full suite command** | `mix check` (D-23 alias — format, Credo, compile --warnings-as-errors, test, Dialyzer, docs; does not exist yet)                                                |
| **Estimated runtime**  | Unknown — the suite has never run to completion (`mix deps.get` currently fails without rebar3 for `:telemetry`). Measure at the end of Wave 0 and record here. |

---

## Sampling Rate

- **After every task commit:** Run `mix test path/to/touched_file.exs`
- **After every plan wave:** Run `mix check` once the alias exists; until then, the individual gate commands (`mix format --check-formatted`, `mix credo`, `mix compile --warnings-as-errors`, `mix test`)
- **Before `/gsd-verify-work`:** `mix check` fully green, **plus** the cross-env compile-parity check (D-19) run explicitly
- **Max feedback latency:** single-file `mix test` target < 30s; full `mix check` unmeasured until Wave 0 completes

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. This table maps **requirements** to their verification
> command and file-existence status; the planner binds task IDs to these rows when PLAN.md is
> written. Every row marked `W0` depends on Wave 0 infrastructure that does not exist today.

| Task ID | Plan | Wave | Requirement | Threat Ref | Test Type | Automated Command | File Exists | Status |
| ------- | ---- | ---- | ----------- | ---------- | --------- | ----------------- | ----------- | ------ |
| TBD | TBD | 1 | QUAL-01 | — | smoke | `rm -rf deps _build && mix deps.get && mix compile --warnings-as-errors` | yes — mix.exs exists, edit in place | pending |
| TBD | TBD | 1 | QUAL-02 | — | static | `mix credo` (blocks on `Warning.IoInspect` and `Warning.IExPry`) plus the SC1 grep over `lib/` | no — W0, `.credo.exs` does not exist | pending |
| TBD | TBD | 1 | REPO-03 | — | smoke | `mix deps.get && mix deps.unlock --check-unused` | yes — mix.exs exists | pending |
| TBD | TBD | 1 | REPO-04 | — | integration | CI matrix job green on each declared Elixir/OTP pair | no — W0, CI is greenfield | pending |
| TBD | TBD | 1 | REPO-05 | — | integration | `mix check` locally; `.github/workflows/ci.yml` in CI | no — W0, CI is greenfield | pending |
| TBD | TBD | 1 | TEST-01 | — | static + unit | SC1 grep for `Mix.env()` over `lib/` returns nothing; `mix test test/commanded/command_action_mapper_test.exs` asserts real Ash records | no — W0, rewrite required per D-17 triage | pending |
| TBD | TBD | 1 | TEST-02 | — | unit | `mix test test/commanded/verifiers/` post-rewrite, using `Code.compile_string` + `assert_raise` | no — W0, 7 files need rewrite | pending |
| TBD | TBD | 1 | TEST-03 | — | unit | New tests exercising generated aggregate, projector, router and event-handler modules | no — W0, `test/support/` fixtures do not exist | pending |
| TBD | TBD | 1 | TEST-04 | — | unit | `mix test test/commanded/command_action_mapper_test.exs` post-rewrite | no — W0, fixture and the `:by_id` fix required first | pending |
| TBD | TBD | 1 | TEST-06 | — | unit / integration | Dispatch-level tests per D-15; `seed: 0` removed, suite run repeatedly under random seed in CI | no — W0, per-test Commanded app case helper does not exist | pending |
| TBD | TBD | 1 | SC2 (D-19) | — | integration | Compile the parity fixture under `MIX_ENV=dev` and `MIX_ENV=test`, compare generated module sets | no — W0, parity fixture does not exist | pending |

> Status legend: pending, green, red, flaky.
>
> The SC1 grep referenced above is the success-criterion command from ROADMAP.md, which matches
> `Mix.env()`, `IO.puts` and `IO.inspect` in a single alternation. It is written out in ROADMAP.md
> rather than repeated here, because a literal alternation character cannot appear in a table cell.

---

## Wave 0 Requirements

- [ ] `test/support/parity/*.ex` — D-19 cross-env fixture; must be dependency-free and reachable from both `:dev` and `:test` `elixirc_paths`
- [ ] `test/support/test_domain.ex` + a resource fixture (e.g. `test/support/widget.ex`) — ETS-backed shared fixture; covers TEST-03, TEST-04
- [ ] Per-test Commanded application case helper (e.g. `test/support/commanded_app_case.ex`) — unique named app + `InMemory` store, torn down in `on_exit`; covers TEST-06
- [ ] `.credo.exs` — checked in, default strictness; covers QUAL-02 enforcement
- [ ] `.dialyzer_ignore.exs` — seeded after the first real `mix dialyzer` run; covers REPO-05
- [ ] `.github/workflows/ci.yml` — greenfield; covers REPO-04, REPO-05
- [ ] `mix.exs` aliases `setup` and `check`, plus `elixirc_paths/1` — covers D-13, D-23, D-25
- [ ] Framework installs — `{:credo, ...}`, `{:dialyxir, ...}`, `{:excoveralls, ...}`, `{:usage_rules, ...}`, and the `:commanded` / `:eventstore` declarations, followed by `mix deps.get`

**Blocking prerequisite:** `mix deps.get` currently fails without rebar3 (`:telemetry`). The `setup`
alias (D-25) must land before any other Wave 0 item can be verified locally.

**Note:** no pre-existing test infrastructure covers any of these. This phase is explicitly building
the infrastructure the other twelve phases assume exists.

---

## Manual-Only Verifications

| Behavior                                                         | Requirement   | Why Manual                                                                                                                                       | Test Instructions                                                                                                                                                                 |
| ---------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fresh-clone bootstrap actually works on a machine without rebar3 | QUAL-01 / SC1 | CI images pre-install rebar (`erlef/setup-beam@v1` defaults `install-rebar: true`), so CI cannot observe the failure mode SC1 is written against | On a machine with no rebar3 on `PATH`: `git clone` to a new directory, run `mix setup`, then `mix compile --warnings-as-errors`. Both must succeed without an interactive prompt. |
| Deleting a verifier makes its rejection test fail                | TEST-02 / SC3 | Proving a test *would* fail requires mutating source, which no automated gate does                                                               | Comment the verifier out of the extension's `verifiers/0` list, run `mix test test/commanded/verifiers/`, confirm a failure, then restore.                                        |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency measured and recorded (currently unknown — suite has never completed)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
