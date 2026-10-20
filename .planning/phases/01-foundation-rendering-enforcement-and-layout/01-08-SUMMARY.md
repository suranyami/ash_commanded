---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 08
subsystem: security
tags: [cr-03, atom-exhaustion, denial-of-service, parameter-transformer, tdd]

# Dependency graph
requires:
  - phase: 01-foundation-rendering-enforcement-and-layout
    plan: 07
    provides: the complete Phase 1 baseline this gap-closure plan branches from
provides:
  - an atom-cast trust boundary that accepts only atoms the runtime already knows
  - a test that observes the atom table itself, not only the return value
  - a documentation example that no longer teaches unbounded String.to_atom/1
  - a recorded assessment of transaction.ex's bounded sibling conversion
affects: [02, 03, 04, 05, 06, 07]

# Actuals (#2632) — pairs with the plan's estimate on the same chars/4 scale.
actuals:
  tokens: 3163
  tasks: 3
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Trust boundary at the type-conversion edge: only atoms already in the runtime atom table"
    - "Security test observes the mechanism (the atom table), never only the return value"

key-files:
  created:
    - test/ash_commanded/parameter_transformer_atom_cast_test.exs
  modified:
    - lib/ash_commanded/parameter_transformer.ex
    - lib/ash_commanded/transaction.ex
    - .planning/WINDOWS.md

key-decisions:
  - "Option A chosen at the blocking-human checkpoint: existing atoms only, error tuple otherwise"
  - "Options B (resource-derived allow-list) and C (configurable strictness) rejected; reasoning recorded before the behaviour change"
  - "cast_value/2 exposed with @doc false so the error tuple and its message can be asserted directly, which the plan's acceptance criteria require"

patterns-established:
  - "Atom-table observation: String.to_existing_atom/1 raising after the cast proves the atom was never minted"
  - "Rejection messages name the expected shape, never the rejected value"

requirements-completed: [CR-03]

coverage:
  - id: D1
    description: "An unrecognised binary cast to :atom returns an error and the atom is still absent from the runtime afterwards"
    requirement: CR-03
    verification:
      - kind: unit
        ref: "test/ash_commanded/parameter_transformer_atom_cast_test.exs#rejects a binary whose atom the runtime has never seen and creates no atom"
        status: pass
    human_judgment: false
  - id: D2
    description: "A binary whose atom already exists still casts successfully to that atom"
    requirement: CR-03
    verification:
      - kind: unit
        ref: "test/ash_commanded/parameter_transformer_atom_cast_test.exs#accepts a binary whose atom already exists"
        status: pass
    human_judgment: false
  - id: D3
    description: "A value that is already an atom passes through unchanged"
    verification:
      - kind: unit
        ref: "test/ash_commanded/parameter_transformer_atom_cast_test.exs#passes an atom through unchanged"
        status: pass
    human_judgment: false
  - id: D4
    description: "Through transform_params/2, an unrecognised binary leaves the field holding its original binary and mints no atom"
    requirement: CR-03
    verification:
      - kind: unit
        ref: "test/ash_commanded/parameter_transformer_atom_cast_test.exs#leaves an unrecognised binary in place and creates no atom"
        status: pass
    human_judgment: false
  - id: D5
    description: "The rejection message does not contain the rejected binary"
    requirement: CR-03
    verification:
      - kind: unit
        ref: "test/ash_commanded/parameter_transformer_atom_cast_test.exs#the rejection message does not echo the rejected binary"
        status: pass
    human_judgment: false
  - id: D6
    description: "The @moduledoc example no longer teaches String.to_atom/1 and transaction.ex records its bounded input set"
    verification:
      - kind: other
        ref: "grep -c 'String.to_atom(' lib/ash_commanded/parameter_transformer.ex == 0; transaction.ex carries the T-01-DO-04 assessment comment"
        status: pass
    human_judgment: false
  - id: D7
    description: "WR-04 is tracked as WINDOWS.md entry 7 with consistent counters"
    verification:
      - kind: other
        ref: "gsd_run windows append --kind todo --phase 01; open_count 5 -> 6, total_count 6 -> 7"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-10-20
status: complete
plan_head_before: d23a205d0e6d6290f5ce232e44e7c22a5accf1b9
plan_head_after: 27e9ba85fe1694b98a07ee8f7cc08e6d94fd3888
---

# Phase 1 Plan 08: Atom-Cast Trust Boundary Summary

**Caller-supplied command parameters can no longer mint atoms: the `:atom` cast accepts
only atoms the runtime already knows, returns an error tuple otherwise, and a test
proves it by observing the atom table rather than the return value.**

## Performance

- **Duration:** 25 min
- **Tasks:** 3
- **Files modified:** 4
- **Test suite:** 271 tests, 0 failures (baseline 265; +6 new)

## Task 1: Trust Boundary Decision (checkpoint:decision)

**Decision:** Option A — `existing-atoms-only` (committed in `e226fb4`).

When `cast_value/2` is asked to cast a binary to `:atom`, it accepts the value only if
the atom already exists in the runtime atom table. Otherwise it returns an error tuple
in the same shape the date, integer and float clauses return.

### Why Option A

- It is one clause change with no signature change to the public `transform_params/2`.
- It matches the boundary Ecto and Ash already hold at their own edges, and the
  boundary a reader expects from a library that accepts external data.
- It fits the existing contract exactly: every other cast type already returns an
  error tuple for unparseable input, and `apply_transform/2` already keeps the
  original value when a cast errors. No new special case is introduced.
- Atoms are never garbage collected on the BEAM, so unbounded `String.to_atom/1` on
  caller-controlled command data is an atom-table exhaustion denial of service. The
  affected function sits on the command-dispatch path this library exists to provide.

### Rejected options

**Option B — allow-list derived from the resource's own attribute and action atoms.**
More precise: it rejects a binary that happens to collide with an unrelated atom the
runtime loaded for another reason. Rejected because `cast_value/2` receives only a
value and a type and has no resource context; implementing it would require threading
resource context through the public, separately tested `transform_params/2`. The
precision gain is unusable by any current caller, because the DSL block that would
declare these casts does not exist yet (plan 01-09 owns it).

**Option C — configurable strictness with a documented default.**
Rejected because a knob defaulting to lax ships the defect by default and is not a
fix, while a knob defaulting to strict is Option A plus an escape hatch nobody has
asked for. An escape hatch from a security boundary is a liability until someone
demonstrates they need it.

### Consequences recorded before changing behaviour

- The error message names the expected type and never interpolates the rejected
  binary. The rejected value is attacker-controlled and unbounded, and the error
  travels toward the consumer's logs; echoing it would turn a rejected input into a
  log-injection and log-volume primitive (T-01-ID-05).
- The proof is an observation of the atom table, not of the return value: a test that
  only asserts `{:error, _}` cannot distinguish "rejected it" from "created it and
  then rejected it" (T-01-BI-21).

## Migration note (behaviour change to shipped dispatch)

This is a deliberate behaviour change to shipped command dispatch. A consumer that
relied on `cast field, :atom` minting a new atom from caller-supplied data will now
receive an error tuple internally, and `apply_transform/2` keeps the original binary
in the field instead of converting it. Per PROJECT.md's Key Decisions, the library
breaks freely on 0.x (currently 0.2.0); this note is the migration record. No
compatibility shim was added. A caller that genuinely needs to mint atoms from caller
data must hold a bounded allow-list of its own.

## RED / GREEN evidence

**RED** (`d06eb38`, `test(01-08)`): `MIX_ENV=test mix test
test/ash_commanded/parameter_transformer_atom_cast_test.exs` reported 6 tests,
5 failures. The target atom-table test failed for the right reason:

```text
Assertion with == failed
code:  assert result.role == binary
left:  :ash_commanded_atom_cast_unknown_1
right: "ash_commanded_atom_cast_unknown_1"
```

The field held a freshly minted atom instead of the original binary, which is exactly
the atom-table growth the fix removes. The four direct `cast_value/2` assertions
failed as undefined/private, which is why GREEN adds the observation seam described
under Deviations. The sixth test (existing-atom conversion) passed in both states, as
the positive-preservation case should.

**GREEN** (`6b5ec45`, `feat(01-08)`):
`MIX_ENV=test mix test test/ash_commanded/parameter_transformer_atom_cast_test.exs`
reported 6 tests, 0 failures. The related pre-existing suites
(`parameter_handling_test.exs`, `parameter_transformer_errors_test.exs`,
`command_action_mapper_test.exs`) reported 42 tests, 0 failures.

## Task Commits

1. **Task 1: record trust boundary decision** — `e226fb4` (docs)
2. **Task 2 RED: failing atom-cast trust boundary tests** — `d06eb38` (test)
3. **Task 2 GREEN: cast only to existing atoms** — `6b5ec45` (feat)
4. **Task 3: stop teaching the defect, settle the sibling site** — `27e9ba8` (docs)

**Plan metadata:** committed separately after this summary.

## Files Created/Modified

- `test/ash_commanded/parameter_transformer_atom_cast_test.exs` — six tests covering
  the rejected binary, the atom table afterwards, the existing-atom success path, the
  atom passthrough, the `transform_params/2` integration, and the non-echo message.
- `lib/ash_commanded/parameter_transformer.ex` — the binary `:atom` clause now uses
  `String.to_existing_atom/1` and returns an error tuple; the module example no longer
  teaches `String.to_atom/1`; `cast_value/2` is public with `@doc false`.
- `lib/ash_commanded/transaction.ex` — a comment recording that the operation-name
  derivation's input set is bounded by the application's compiled command modules.
  No behaviour change.
- `.planning/WINDOWS.md` — entry 7 tracks the deferred WR-04 swallowed-exception
  defect (`open_count` 5 to 6).

## Decisions Made

- Option A at the checkpoint, with B and C rejected for the reasons recorded above.
- The atom-table assertion is the required proof, not the return value.
- `transaction.ex`'s sibling conversion is assessed and left unchanged: both its
  struct and its explicit `:name` are application-supplied, and the derived atom is
  bounded by the set of compiled command modules (T-01-DO-04, accepted).
- `mix check` regenerated two untracked `documentation/dsls/` files (WINDOWS.md
  entry 6, deferred to Phase 7); they were deleted rather than committed, as the plan
  requires.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Exposed `cast_value/2` with `@doc false` to observe the
error tuple directly**

- **Found during:** Task 2 (RED)
- **Issue:** The plan requires assertions on the returned error tuple and on its
  message, but `cast_value/2` was private. A private function cannot be called from
  a test, and `transform_params/2` deliberately discards the error tuple, so neither
  acceptance criterion could be asserted directly.
- **Fix:** Changed the `cast_value/2` clauses from `defp` to `def` and added
  `@doc false` plus a `@spec`. No behaviour changed; the function remains outside the
  documented API surface. The full clause body is otherwise untouched.
- **Files modified:** `lib/ash_commanded/parameter_transformer.ex`
- **Verification:** All six tests pass; `mix compile --warnings-as-errors` and
  `mix credo` are clean.
- **Committed in:** `6b5ec45` (Task 2 GREEN commit)

## Issues Encountered

- The installed `elixir-phoenix` Iron Law hook flags any non-comment
  `String.to_atom(` occurrence. It fired on `transaction.ex`'s accepted, bounded
  conversion (T-01-DO-04) after the assessment comment was added. The plan explicitly
  directs leaving that call site unchanged, and the user's rule prohibits
  `String.to_atom/1` on user input — this value is derived from a command struct's
  `__struct__`, not from external input. The hook is a coarse mechanical check and
  cannot see the assessment; no code was changed to silence it. A future mechanical
  check that understands the allow-listed site would remove the false positive.

## Threat Surface Scan

The plan's threat register is fully accounted for:

| Threat | Disposition | Outcome |
| --- | --- | --- |
| T-01-DO-02 | mitigate | Accepts only existing atoms; proven by atom-table observation |
| T-01-DO-03 | mitigate | Moduledoc example rewritten with the reason beside it |
| T-01-ID-05 | mitigate | Message names the type; the rejected binary is never interpolated |
| T-01-DO-04 | accept | Input-set assessment recorded at the site |
| T-01-BI-21 | mitigate | Test observes the atom table directly after the call |
| T-01-SC-05 | accept | No dependency or lockfile change |

No new threat surface was introduced.

## Next Phase Readiness

- CR-03 is closed with a recorded trust boundary, a mechanism-level test, and a
  migration note.
- The cast contract is uniform again: every failing cast returns an error tuple and
  `apply_transform/2` keeps the original value.
- WR-04 (silently swallowed transform-function exceptions) remains deferred and is
  now visible to the ship gate through `.planning/WINDOWS.md` entry 7.

## Self-Check: PASSED

- `test/ash_commanded/parameter_transformer_atom_cast_test.exs` exists.
- Commits `e226fb4`, `d06eb38`, `6b5ec45`, `27e9ba8` exist in history.
- `mix check` exits 0; `MIX_ENV=test mix test` reports 271 tests, 0 failures.
