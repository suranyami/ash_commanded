# Learnings — carried across the rewrite boundary

**Written:** 2026-09-15, at the close of Phase 1 (Build Integrity), immediately before the decision
to rewrite the library component by component rather than continue refactoring the inherited
implementation.

**Purpose:** everything below was discovered by execution, not by reading. Most of it was invisible
until guards, mocks and stubs were removed. A rewrite that re-discovers any of it has wasted the
phase. This document outlives the current ROADMAP.md and REQUIREMENTS.md.

---

## 1. Why the rewrite

Phase 1 did not set out to evaluate the implementation; it set out to make the test suite capable of
failing. Doing so surfaced nine defects and one structural problem, and the structural problem is
what changed the plan.

A generator audit across all 13 transformers measured:

| Transformer | `quote` blocks | Largest block | Total generated lines |
| ------------- | ---------------- | --------------- | ----------------------- |
| `generate_aggregate_module.ex` | 11 | **225** | **541** |
| `generate_projector_modules.ex` | 11 | 15 | 64 |
| `generate_commanded_application.ex` | 5 | 27 | 60 |
| `generate_event_handler_modules.ex` | 5 | 17 | 47 |
| `generate_main_router_module.ex` | 6 | 20 | 43 |
| `generate_projection_modules.ex` | 3 | 31 | 36 |
| `generate_command_modules.ex` | 1 | 6 | 6 |
| `generate_event_modules.ex` | 1 | 6 | 6 |

Seven generators are proportionate. One is an outlier by an order of magnitude. The distribution
reads as accretion, not convention: the aggregate module grew middleware, transactions, snapshots and
param mapping by inlining each concern into the emitted body, rather than routing to the runtime
modules that already existed. That is why `command_action_mapper.ex` (639 lines) and the generated
`execute/2` (225 lines) implement overlapping concerns.

**The explanation for the distribution is mechanical, and it points at the fix.** The proportionate
generators are proportionate because Commanded supplies a `__using__` macro for what they generate:

| Generator | Largest block | Delegates to |
| ----------- | --------------- | -------------- |
| projector | 15 | `use Commanded.Event.Handler` |
| event handler | 17 | `use Commanded.Event.Handler` |
| router | 20 | `use Commanded.Commands.Router` |
| application | 27 | `use Commanded.Application` |
| **aggregate** | **225** | **nothing — Commanded has no aggregate behaviour** |

A Commanded aggregate is a plain module with `execute/2` and `apply/2`. There is no `use` macro, so
the machinery had to be written — and it was written into the emitted AST instead of into a runtime
module with a `__using__` front door.

**The first design question of the rewrite is therefore: what is `AshCommanded.Aggregate.__using__/1`?**
The other components largely follow from the answer.

### The artifact that settled it

Rendering the generated aggregate for a fixture with ONE command and ONE event produced 333 lines.
Inside `execute/2`:

```elixir
process_command(
  ctx.aggregate, cmd, resource_module, ctx.action_name, ctx.identity_field,
  AshCommanded.TestSupport.Parity.Events.WidgetCreated,
  :erlang.++([],
    :erlang.++([],
      :erlang.++([transforms: [], validations: []],
        :erlang.++([], :erlang.++([], :erlang.++([], []))))))
)
```

Six list concatenations executed on every command dispatch, five of them on empty lists, to build a
value fully known at macro-expansion time. The source (`generate_execute_functions/5`, six separate
`*_arg` variables at lines 253–295, concatenated at 346–355) does not look like this. The render
does. **Reading generated output is a different and more effective review than reading the
generator.**

---

## 2. Assets that survive the rewrite — do not discard

None of the following is generator code. All of it is what makes a rewrite verifiable.

| Asset | Notes |
| ------- | ------- |
| `mix.exs` toolchain | deps, `elixir: "~> 1.18"`, `elixirc_paths/1`, `setup` and `check` aliases, ExCoveralls + Dialyzer config |
| `.credo.exs` | default strictness, blocking; 15 reasoned inline disables citing roadmap phases |
| `.dialyzer_ignore.exs` | seeded verbatim from a real run, 4 entries |
| `test/support/widget.ex`, `test_domain.ex`, `context_widget.ex`, `custom_action_widget.ex` | ETS-backed fixtures on the `:test` elixirc path |
| `test/support/commanded_app_case.ex` | per-test uniquely-named Commanded applications (D-15) |
| `test/support/parity/` + `scripts/compile_parity.sh` | the cross-environment visibility mechanism — see §6 |
| `test/test_helper.exs` | exactly `ExUnit.start()`; no exclusions, no fixed seed |
| The test suite | 176 tests, 0 failures, stable across 45+ consecutive full-suite runs, zero mocking |
| `.github/workflows/` | if plan 01-08 lands before the rewrite begins |

**A rewrite judged against a green suite and green CI is a fundamentally different proposition from
one judged against the state this repository was in on 2026-09-12, when `mix test` could not
complete and `mix deps.get` failed outright.**

---

## 3. Library defects found — all previously unreachable

Each was concealed by a `Mix.env()` guard, an `Application.get_env` knob, a `Code.ensure_loaded?`
fallback, or a mocked return. None was discoverable by reading.

1. **`Ash.Query.for_read(:by_id)`** — `command_action_mapper.ex` (was :498, :540). Ash has no
   built-in `:by_id` read action and nothing in the repo declared one, so `execute_update/5` and
   `execute_destroy/5` raised `NoSuchAction` the moment the mock was removed. Fixed to `:read`.
   *Found by: removing the mock.*

2. **Context never reached declarative changes.** All five `execute_*` paths called
   `Ash.Changeset.set_context/2` (or `Ash.Query.set_context/2`) AFTER `for_action`/`for_read`. Ash
   runs declarative changes, validations and preparations DURING changeset construction, so context
   set afterwards arrived too late for any of them. Fixed by threading `context: context` through
   `for_action`/`for_read`/`ActionInput.for_action` opts.
   *Found by: rewriting a test to assert on a persisted attribute written by a real change, instead
   of on the mapper's own return value — which carried the context and so passed regardless.*

3. **`Commanded.Aggregates.Aggregate.Snapshotter` has never existed** in any Commanded version,
   verified against `deps/commanded` 1.4.11 and current upstream docs. `snapshot_adapter.ex`
   declared `@behaviour` for it behind a `Code.ensure_loaded?` guard that was permanently false, so
   the behaviour was never attached and the compiler never checked those four functions against
   anything. Commanded's real snapshotting is internal (`Commanded.Snapshotting`), configured
   per-aggregate via a plain map, with no pluggable adapter behaviour.

4. **`Ash.run_action/3` does not exist.** The real function is `Ash.run_action/2`
   (`deps/ash/lib/ash.ex:1441`), taking an `%Ash.ActionInput{}` — not `(resource, action, params)`.
   Generated event-handler code called the 3-arity form; fixed in plan 01-07 to dispatch by action
   type. **STILL OPEN:** `generate_projector_modules.ex:359` calls `Ash.run_action(changeset, action)`
   — arity 2 exists so it compiles with no warning, but the arguments match neither `(input, opts)`.
   Latent, no compile signal.

5. **Router generation never fires.** `GenerateCommandedApplication` is a DOMAIN transformer that, at
   `generate_commanded_application.ex:72`, creates a module whose body invokes Commanded's `router/1`
   macro, which reads `__registered_commands__/0` from a router produced by
   `GenerateMainRouterModule` — a RESOURCE transformer that has not compiled yet. Raises
   `function ...Router.__registered_commands__/0 is undefined`. **Confirmed twice**: once from an
   inline test domain, once from an equivalent fixture placed in `test/support/` (so compile order is
   not the variable). The library generates routers that are never generated.
   `test/commanded/transformers/commanded_application_integration_test.exs.phase2-blocked` is
   quarantined for this reason.

6. **`Supervisor.child_spec({Supervisor, ...})` does not work** — surfaced the first time anything
   called the generated `child_spec/0`. Fixed to build the map directly.

7. **Dead clauses in every generated projector.** `perform_action/2` was emitted for every action type
   regardless of what the resource declared, producing `this clause is never used` warnings in every
   generated projector the library has ever produced. Invisible until a resource compiled in `:dev`.

8. **Two projector/projection bugs** in `generate_projection_modules.ex` and
   `generate_projector_modules.ex` — *"no projector had ever successfully processed a real event
   before this plan"* (plan 01-06).

9. **A seventh `Code.ensure_loaded?` fiction, in `test/`.** D-07 removed six from `lib/`. Nobody
   searched `test/`. `commanded_application_integration_test.exs:28` guarded its entire
   `commanded do application do ... end end` block behind `Code.ensure_loaded?(Commanded.Application)`
   — and Commanded was not a declared dependency until this phase, so the block was never defined and
   the "application integration test" never once exercised application generation.
   **A rewrite should sweep `grep -rn "Code.ensure_loaded?" lib/ test/` as a matter of course.**

---

## 4. Framework facts established

### Ash

- `Ash.run_action/2` takes `%Ash.ActionInput{}` + opts. There is no `/3`.
- Context MUST be passed through `for_action`/`for_read`/`ActionInput.for_action` opts. `set_context/2`
  afterwards is too late for declarative changes, validations and preparations.
- There is no built-in `:by_id` read action. `defaults [:read, ...]` gives `:read`.
- `uuid_primary_key/1` hides every option but `:name` and defaults `writable?: false` — it cannot
  accept a client-supplied id. Declare the attribute longhand when the action must accept one.
- `Ash.DataLayer.Ets` with `private?: true` gives per-process tables — which means a record written in
  one process is invisible in another. Relevant to any cross-process test.
- Resources with no data layer default to `Ash.DataLayer.Simple` and compile fine — useful for
  fixtures that exist to be compiled rather than written to.

### Commanded (1.4.11)

- No `Commanded.Aggregates.Aggregate.Snapshotter`. No pluggable snapshot adapter behaviour at all.
- Aggregates are plain modules with `execute/2` and `apply/2` — **no `use` macro, no callbacks.**
  This single fact explains the entire generator size distribution in §1.
- `use Commanded.Event.Handler`, `use Commanded.Commands.Router` and `use Commanded.Application` DO
  provide `__using__` macros, which is why those generators are thin.
- `Commanded.Application.start_link(name: unique_atom)` supports runtime names, and the `InMemory`
  adapter derives its event-store name from the application name — giving free per-name isolation.
- Generated aggregate `execute/2`/`apply/2` and projector/handler `handle/2` are plain functions,
  callable directly with no Commanded process running. Per-test applications are only needed for
  tests exercising the full `Router.dispatch/1` path.

### Spark (2.7.2)

- **Verifier errors are NOT catchable with `assert_raise`.** Spark runs verifiers via Elixir's
  `@after_verify` hook (`deps/spark/lib/spark/dsl.ex:464`), which converts raised errors to stderr
  warnings. Use `Spark.Test` (`deps/spark/lib/spark/test.ex`) — `assert_dsl_error/1,2`,
  `refute_dsl_errors/1`, `dsl_errors/1`. Its moduledoc states the problem explicitly.
  **This invalidated a locked decision (D-14) mid-phase**, and note the cause: D-14 was made against
  Spark 2.3.5 and the same phase's own dependency bump (REPO-03) moved us to 2.7.2. A decision can be
  invalidated by a later decision in the same phase.
- `Transformer.get_persisted(dsl_state, :module)` gives the resource module. Do not reconstruct it by
  splitting and re-concatenating another module's name — `generate_aggregate_module.ex:235` did this
  while line 97 of the same file already had the correct value.
- Compile-stage contract: **Transformers** (during compilation, dependency order, may modify DSL
  state) → **Persisters** (after all transformers, write only to the persisted map) → **Verifiers**
  (after compilation, read-only, no compile-time dependencies).
- Upstream guidance: *prefer a verifier over a transformer when you only need to validate*; *put
  introspection in a `ModuleName.Info` module*.

### Tooling

- `:meck` queries `:cover` to preserve a mocked module's coverage state, and `:cover.call/1` STARTS
  the cover server on demand. Two concurrent `async: true` `:meck.new/2` calls race on that startup;
  the loser gets `{:error, {:already_started, pid}}` against a success-only match. **This happens even
  with coverage switched off.** Grep for `:meck\.` as well as `with_mock` — the raw API does not
  match the latter.
- `mix compile` builds `lib` plus `elixirc_paths` only — **not** `test/**/*_test.exs`. A defect in
  code generated when a test file compiles is invisible to `mix compile --warnings-as-errors` and
  visible only under `mix test`. Any CI treating the former as "the warning gate" has a blind spot
  exactly the size of its generated-in-test code.

---

## 5. Rules established — these should be foundational in the rewrite, not remedial

Currently recorded as FOUND-06, FOUND-07 and a re-framed QUAL-03.

1. **Generated code is thin wiring; logic lives in hand-written runtime modules.** A generated clause
   carries only the per-entity literals that vary and delegates to a normal module that can be
   unit-tested, stepped through, and read without mentally expanding a `quote`.
2. **Anything computable at macro-expansion time is computed there** and `unquote`d as a literal,
   never reassembled at runtime.
3. **Measure the OUTPUT, not the generator.** Target: a generated clause under ~10 lines; no `quote`
   block over 40 lines. Splitting a fat generator into several generator modules satisfies a
   line-count criterion while changing nothing about what is emitted.
4. **Derive from `Transformer.get_persisted/2`**, never by module-name surgery.
5. **Prefer a verifier over a transformer** when only validating.
6. **Introspection belongs in `ModuleName.Info`.**
7. **Golden renders of generated output, diffed in CI.** The defect in §1 was always present and
   always visible in principle; it became obvious only when rendered.

---

## 6. Techniques worth reusing

**Making generated code visible to the dev compiler.** Generated modules exist only when a
DSL-using resource compiles. Every such resource lived under `test/`, so `_build/dev` contained none
and cross-environment claims were unprovable. One line fixes it:

```elixir
defp elixirc_paths(:dev), do: ["lib", "test/support/parity"]
```

The fixture is deliberately dependency-free and has no data layer — *"this resource exists to be
compiled, not written to, and a real data layer is one more thing that could differ between
environments."* `scripts/compile_parity.sh` checks an explicit list of expected modules loads under
each environment rather than diffing directories, because a wholesale diff is swamped by legitimate
test-only modules and a check that cries wolf gets disabled.

**Unplanned payoff:** this turned the compiler into a reviewer of generated output, and it
immediately found the dead `perform_action/2` clauses (§3.7) that had existed in every generated
projector since the library was written.

**Rendering compiled modules back to source.** Prototype committed at
`scripts/render_generated.exs` (commit `1172c0e`). Run it with
`mix run scripts/render_generated.exs <Module.Name> [...]`.
`:beam_lib.chunks(path, [:debug_info])` returns `{:debug_info_v1, :elixir_erl, {:elixir_v1, map, _}}`
whose `map.definitions` holds per-function Elixir AST; `Macro.to_string/1` + `Code.format_string!/1`
render it. Caveat: this is post-macro-expansion, so `use X` appears as the functions it injected.
FOUND-07's `mix ash_commanded.dump` should instead render the AST *before* `Module.create/3`, showing
what the transformer wrote rather than what the compiler produced.

**Verifying a stub rather than mocking.** When testing `GenerateCommandedApplication` — where mocking
caused a race and compiling a real domain hit defect §3.5 — the working answer was to hand-define a
real, empty `Commanded.Commands.Router` at the exact module name the generated code expects. That
supplies the missing prerequisite the broken transformer would have supplied, isolating one
transformer's behaviour from another's defect, with no mock and no race. A stub is a real module that
genuinely satisfies a contract; a mock intercepts and fakes.

**Verifying flakiness.** Seeds change test ORDER; they do not change whether two `async: true` files
call into a shared resource at the same instant. A race needs **repetition under load**. A suite that
passes 6 seeds and 2 runs can still be 40% flaky — measured here by running the full suite 5 times
(2 failures), then 10 times after the fix (0 failures). Also: a test passing in isolation while
failing in the full suite is the exact SC5 condition and should be checked deliberately, not assumed.

---

## 7. Process learnings

- **Subagent reports need independent verification.** Several were accurate but incomplete: "163
  tests, 5 failures" omitted that a compile error aborted the run; "stable across 6 seeds" missed a
  40% race; "no `with_mock` in `test/`" was true while two files used the raw `:meck` API.
  Every claim in this phase that was checked, was checked because it was checked — not because it was
  doubted.
- **Executors refusing to bypass a blocker was consistently correct.** Signing failures, a worktree
  base mismatch, and a locked-decision conflict were all escalated rather than worked around, and in
  every case the escalation was right.
- **`git commit --allow-empty` does NOT ignore the index** — it sweeps staged files into the probe
  commit. Combined with `reset --hard`, this destroyed staged work once. Never probe signing while
  anything is staged.
- **Read `git` exit codes directly, never through a pipeline.** `git commit ... | tail` then `$?`
  yields tail's status; a failed commit reads as success.
- **Uncommitted configuration is indistinguishable from unset configuration.** A `--hard` reset
  silently reverted `workflow.use_worktrees: false` in `.planning/config.json`, which re-blocked the
  next dispatch.
- **The harness forks worktrees from `origin/HEAD`.** On a branch well ahead of it, a worktree does
  not even contain the phase's own PLAN.md. `worktree.base-check` detects this
  (`shouldDegrade: true`, `head-diverged-from-fork`) and the documented answer is sequential
  execution — run that check before dispatching, not after.

---

## 8. Open items at the boundary

| Item | State |
| ------ | ------- |
| `Ash.run_action(changeset, action)` at `generate_projector_modules.ex:359` | Open. Arity exists, arguments wrong, no compile signal. |
| Router generation never fires (§3.5) | Open, corroborated twice. Blocks any real application-generation test. |
| `commanded_application_integration_test.exs.phase2-blocked` | Quarantined. Restore the extension only once §3.5 is fixed, and delete its stale `Code.ensure_loaded?` guard at the same time. |
| `CLAUDE.md` documents three verifiers that do not exist | `ValidateCommandActions`, `ValidateCommandHandlers`, `ValidateCommandNameConflict`. Treat all CLAUDE.md factual claims as unverified. |
| `spark.cheat_sheets` covers only `AshCommanded.Commanded.Dsl` | Not `DomainDsl`. |
| `mix.exs` `files:` omits `documentation/` and `cheatsheets/` | The published package's docs are incomplete. |
| Plan 01-08 (CI matrix, usage-rules sync) | Not started at the time of writing. |
| `workflow.use_worktrees: false` | Correct while this branch runs ahead of `origin/HEAD`; revert after merge. |

---

*This document is deliberately independent of ROADMAP.md and REQUIREMENTS.md, both of which are
expected to be replaced. Nothing here should need re-discovering.*
