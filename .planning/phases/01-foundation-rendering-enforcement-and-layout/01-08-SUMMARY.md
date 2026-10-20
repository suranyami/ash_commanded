---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 08
subsystem: security
tags: [cr-03, atom-exhaustion, denial-of-service, parameter-transformer]
status: in-progress
---

# Phase 1 Plan 08: Atom-Cast Trust Boundary Summary

**Caller-supplied command parameters can no longer mint atoms; the cast accepts only
atoms the runtime already knows and returns an error tuple otherwise.**

## Task 1: Trust Boundary Decision (checkpoint:decision)

**Decision:** Option A — `existing-atoms-only`.

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

The change is a behaviour change to shipped dispatch: a consumer that relied on new
atoms being minted from caller data now receives an error and keeps the original
binary. PROJECT.md's Key Decisions license breaking freely while the library is on
0.x (currently 0.2.0), so the mitigation is an honest migration note rather than a
compatibility shim. This note is the migration record.

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

## Results

Task execution results are recorded below once Tasks 2 and 3 complete.
