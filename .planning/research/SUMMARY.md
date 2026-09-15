# Project Research Summary

**Project:** AshCommanded v0.3 Library Rewrite
**Domain:** Elixir/Spark DSL extension (CQRS/Event Sourcing code generation for Ash Framework)
**Researched:** 2026-09-15
**Confidence:** HIGH overall, with several MEDIUM-confidence advisory items. The one architectural question the research left open was resolved experimentally by the orchestrator — see "THE COMPILE-ORDER QUESTION" below.

## Executive Summary

AshCommanded's v0.3 rewrite is a code-generation library correcting itself against its own audit: the previous generation layer let the aggregate generator balloon to 861 lines/225-line quote blocks because Commanded supplies `__using__` macros for routers, event handlers and applications but not for aggregates, so all the missing machinery got hand-inlined into emitted AST instead of a runtime module. Every research thread converges on the same fix shape — write `AshCommanded.Aggregate.__using__/1` as a first-class, hand-authored front door (precedent: `GenServer`, `AshOban.DefineActionWorkers`), keep generated clauses to a single pattern-match delegating into hand-written, unit-testable runtime modules, and enforce this mechanically by rendering emitted code to text (`mix ash_commanded.dump`) and running Credo/`ex_dna` checks against the *rendered output*, not generator source — because no existing Elixir tool measures macro-emitted code size or shape. The renderer is therefore not a convenience item; it is the precondition for enforcing three of the eleven rewrite rules and for the entire "render and approve" per-component review method.

The recommended approach: build the renderer and golden-file harness first (Foundation phase), add `.Info` modules everywhere (there are currently zero, despite being a stated rule), split `lib/` into resource/domain/runtime directories mirroring `ash_graphql`'s mature layout, and rewrite the aggregate generator around a hand-written `Runtime`/`Info` pair exactly as AshOban does for scheduled workers. Two of the eleven rewrite rules (DRY-detection and the size/shape gate) have solid off-the-shelf or cheaply-buildable tooling; one rule ("no double-handling") has **no mechanical check at all** and must remain a human code-review discipline, stated plainly rather than papered over.

The largest remaining risk is the single-pass nature of Commanded's event upcaster: a naive version-chain upcasting DSL will silently under-upcast old events on replay. This is judged the highest-value DSL design constraint in the whole research set because a mistake here is expensive (re-derive read models from the event store) rather than a quick patch.

## Key Findings

### Recommended Stack

All stack recommendations are dev/test-only tooling; no new runtime dependencies. `ex_dna` (Credo plugin, AST-based structural clone detection) is a genuine off-the-shelf answer to the DRY rule and should replace Credo's built-in `DuplicatedCode` check (Type-I-only, known gaps with macro-heavy code). `sourceror`'s pin should be bumped from `~> 1.8` to `~> 1.12` (already a dependency). For golden-file/snapshot testing, **do not adopt** `mneme`/`assert_value`/`snapshy` — all embed the expected value as a literal inside the test file, unworkable for 300+-line renders that need to be reviewable in a normal PR diff; hand-roll a plain file-based golden harness instead (2-4 hours, ExUnit + `File.read!`/`write!`, no new dependency). Custom Credo checks (grep-style, using `Credo.Code.prewalk/2`) are the cheap, precise mechanism for two anti-patterns: `Code.string_to_quoted!`/`eval_string` calls in transformer code, and `Module.concat` fed by `Module.split` (module-name surgery).

**Core technologies:**

- `ex_dna` 1.5.1 — structural AST clone detection — the one rewrite rule with a genuine off-the-shelf answer; MEDIUM-HIGH confidence, verify its Elixir/OTP floor at adoption time (not independently confirmed)
- `credo` 1.7.18 — already a dependency; host for all custom in-repo checks via `.credo.exs` `requires:` glob
- `sourceror` 1.12.2 — AST-shape traversal for custom checks (quote-block extraction, unquote-ratio counting); bump the stale `~> 1.8` pin
- Hand-rolled golden-file harness — not a library; the standard pattern for large, PR-reviewable generated-code diffs

**No tool exists** for measuring emitted macro output size/shape directly, or for the "no double-handling" rule (a data-flow ownership question outside AST-shape matching). Both require the renderer to exist first, then either a small stdlib-only script (size/shape) or human code review (double-handling) — state this plainly rather than presenting a check that doesn't exist.

### Expected Features (DSL surface / Spark API capabilities)

Spark 2.7.2 (the version actually resolved — **not** 2.3.5 as stale docs claim) provides substantial machinery the previous implementation didn't use:

**Must have (already-available Spark mechanisms the rewrite should adopt, not reinvent):**

- `identifier:` on an Entity turns on automatic duplicate-name checking — replaces hand-written `ValidateCommandNames`/`ValidateEventNames`
- `singleton_entity_keys` — automatic "at most one" checking, no custom verifier needed
- `use Spark.InfoGenerator` — generates `.Info` module accessors for free; AshCommanded currently has **zero** `.Info` modules despite this being a stated rewrite rule
- Spark auto-prepends `VerifyEntityUniqueness` and `VerifySectionSingletonEntities` to every extension — some planned hand-written verifiers are already redundant
- `Spark.Formatter` plugin for deterministic section ordering in generated/hand-written DSL bodies

**Should have (differentiators / correctness-critical DSL design):**

- Declarative event upcasting that composes intermediate transformations at generation time into one `upcast/2` clause per historical struct type, each returning the *current* struct directly — because Commanded's `Upcaster.upcast/2` is called exactly once per event, never chained (verified at all 5 call sites)
- `{:spark_function_behaviour, ...}` schema type for `changes(fn event -> ... end)`-style DSL ergonomics in projections (the exact mechanism Ash itself uses)

**Caveat/gotcha, not a feature to defer:** `{:behaviour, module}` and `{:spark_behaviour, ...}` schema types do **not** verify the supplied atom actually implements the behaviour — only `is_atom/1` is checked. If AshCommanded needs "this module must implement `AshCommanded.Middleware`" enforced, that must be an explicit verifier calling `Spark.implements_behaviour?/2`, not the schema type.

**Defer:** `top_level?` section flag (removing a layer of nesting on `application`) — legitimate simplification, not required for correctness.

### Architecture Approach

Every mature Ash extension inspected (`ash_graphql`, `ash_json_api`, `ash_oban`, `ash_authentication`) encodes the resource/domain DSL boundary directly in the directory structure (`resource/{dsl.ex,info.ex,transformers/,verifiers/}` and `domain/{...}` as siblings), not just in extension registration — plausibly part of why AshCommanded's domain router transformer ended up attached to the wrong extension in the first place. The recommended `lib/` layout mirrors this split, adds an `aggregate.ex` + `aggregate/{runtime.ex,info.ex,snapshotting.ex}` triad for the new hand-written aggregate front door, and moves the renderer to `mix/tasks/`.

**Major components:**

1. **`AshCommanded.Aggregate` (`__using__/1` front door)** — accumulates command-to-event mappings via `Module.register_attribute(accumulate: true)`, materializes thin `execute/2`/`apply/2` clauses once via `@before_compile`, following the exact five-part anatomy already proven by Commanded's own `Router`/`EventHandler`/`Application` macros (deferred codegen, `@behaviour`, accumulator attribute, `defoverridable` defaults, heavy logic never inlined in `quote`)
2. **`AshCommanded.Aggregate.Runtime`** — hand-written, plain, unit-testable module owning identity checks, middleware invocation, error wrapping — everything that used to be inlined per-clause
3. **`AshCommanded.Aggregate.Info` / per-extension `.Info` modules** — the ONE place that knows how to look up per-command configuration; replaces runtime AST/list reassembly with a single lookup, closing the complete `.Info` gap (zero exist today)
4. **Domain-level router/application transformers** — must move from the resource extension (where they run once per resource, unable to see sibling resources) to the domain extension. The compile-order mechanism that makes this safe is settled below.

### Critical Pitfalls

1. **Router/application generation never fires (confirmed defect)** — `Commanded.Commands.CompositeRouter`'s `router/1` macro calls `router_module.__registered_commands__()` at macro-expansion time, requiring the router module already compiled; the current domain transformer runs during the domain's own ordinary compile pass with no such guarantee. Fix: generate router and application from the same transformer's sequential `Module.create/3` calls, or have the domain transformer read each resource's persisted state directly.
2. **Chained upcast assumption** — `Commanded.Event.Upcaster.upcast/2` is called exactly once per stored event, never re-dispatched on its own result. A per-version-hop upcaster chain will silently under-upcast old events on replay — the highest-value DSL design constraint found, and the most expensive to recover from (requires re-deriving read models from the event store, not a code fix).
3. **Reintroducing a fictional snapshot adapter behaviour** — `Commanded.Aggregates.Aggregate.Snapshotter` has never existed in any Commanded version; real snapshotting is `Commanded.Snapshotting`, an internal, non-pluggable mechanism configured via a plain map (`snapshot_every`/`snapshot_version`) at the application-config level. Generate a config fragment, not an adapter behaviour.
4. **Runtime AST reassembly of compile-time-known values** — the confirmed instance (six nested `:erlang.++/2` calls building `[transforms: [], validations: []]` on every dispatch) is invisible from reading generator source and visible only in rendered output — the direct justification for the renderer/golden-render requirement.
5. **Module-name surgery instead of holding the atom already in scope** — `Module.concat` built from string-split re-concatenation is invisible to the Elixir compiler's dependency tracker, causing stale-BEAM recompilation bugs; always derive from `Transformer.get_persisted/2`.

## THE COMPILE-ORDER QUESTION — RESOLVED EXPERIMENTALLY

This section originally recorded an unresolved conflict between two research documents. The orchestrator settled it by experiment on 2026-09-15. Both the conflict and the resolution are recorded, because the reasoning is reusable.

### The conflict as researched

- **FEATURES.md's position:** mark the domain transformer `after_compile?() -> true`, which Spark defers execution into `@after_verify` — a phase guaranteed to run after every module in the compilation unit has finished compiling. Cites `deps/spark/lib/spark/dsl.ex:470-474`, `deps/spark/lib/spark/dsl/extension.ex:693-699,521-529`, and Ash's own `Ash.Domain.Verifiers.ValidateRelatedResourceInclusion` as precedent (note: that precedent is a *verifier*, read-only by contract — using `after_compile?` on a *transformer* that must also `Module.create/3` is a different, less-precedented case).
- **ARCHITECTURE.md's position:** no deferral needed. Claimed `Ash.Domain.Dsl`'s `resource` entity (typed `{:spark, Ash.Resource}`, no `no_depend_modules` opt-out) forces every listed resource to compile before any domain transformer runs, via `Spark.Dsl.Extension.expand_alias/2` creating compile-time dependency edges.

### Source verification — ARCHITECTURE.md's stated mechanism is wrong

1. `Spark.Dsl.Extension.EntityOption.value_and_function/6` (`deps/spark/lib/spark/dsl/extension/entity_option.ex`) consults the option's declared TYPE only for the `:quoted` case (`Macro.escape`). Dependency creation is gated by a three-branch `cond`: `field in modules` -> `expand_alias/2` (creates the edge), `field in no_depend_modules` -> `expand_alias_no_require/2` (explicit opt-out), `true` -> value returned **unexpanded**, no edge at all. The identical `cond` appears for entity positional args at `extension.ex:1483-1490`.
2. `Ash.Domain.Dsl`'s `resource` entity (`deps/ash/lib/ash/domain/dsl.ex:130-146`) declares `modules: []` and no `no_depend_modules` key. `:resource` matches neither branch and falls to `true ->`.
3. There is no value-level `defp validate_type({:spark, _}, key, value)` clause in `deps/spark/lib/spark/options/options.ex` that would force compilation during validation. (`validate_type({:spark, module})` at line 1830 validates the type *declaration*, not a value.)

### The experiment

A minimal probe was compiled under `MIX_ENV=test` with three modules in **separate files**, so compile order was decided by the dependency graph rather than top-to-bottom evaluation:

- `Probe.Ext` — a Spark extension with one ordinary (non-`after_compile?`) domain transformer
- `Probe.Widget` — an `Ash.Resource` with an ETS data layer
- `Probe.Domain` — an `Ash.Domain` listing that resource

The transformer called `Spark.Dsl.Extension.get_persisted(resource, :primary_key)` **first**, before any `Code.ensure_compiled/1` or `Code.ensure_loaded?/1` — an initial version of the probe called `ensure_compiled` first and was discarded, because that call can itself force compilation and would have manufactured the result it measured. `:primary_key` was chosen deliberately: `get_persisted(resource, :module, _)` short-circuits for atoms and would have proved nothing.

**Result:**

```text
=== PROBE: domain transformer for Probe.Domain ===
resources seen: [Probe.Widget]
  Probe.Widget
    get_persisted(:primary_key) [measured first] = {:ok, [:id]}
    module_loaded? [after]                       = true
=== PROBE END ===
```

### Verdict

**ARCHITECTURE.md's conclusion is CORRECT; its stated reason is not.** An ordinary domain-level transformer can read resource-level persisted state directly. No `after_compile?` deferral is required.

**The real mechanism** is `persisted!/3` at `deps/spark/lib/spark/dsl/extension.ex:149`:

```elixir
defp persisted!(resource, key, default) do
  resource.persisted(key, default)
rescue
  ...
end
```

It is a **remote function call on the resource module**. Inside Elixir's parallel compiler, a remote call to a module still being compiled causes the compiler to block until that module is available. So the ordering is guaranteed on demand at call time, not by a declared dependency edge — which is why ARCHITECTURE.md could reach the right answer from the wrong premise.

### Consequences for design

- The domain transformer approach is viable and is the recommended design. `after_compile?() -> true` remains a documented fallback but is not needed.
- **Deadlock is the risk to watch, not missing state.** Because ordering comes from an on-demand compiler block, a genuine cycle would hang rather than error: if a *resource*-level transformer ever needs to call into its *domain*, and the domain transformer calls back into the resource, the parallel compiler can deadlock. The probe confirmed that Ash's `use Ash.Resource, domain: Probe.Domain` back-reference does **not** create such a cycle. Any future design that has resource transformers reading domain state must be checked against this explicitly.
- PITFALLS.md separately recommends Application and Routers be planned as **one coupled unit**, since the ordering defect spans both. This differs from the user's stated build order (application third, routers later) and should be flagged to the roadmapper. Note this recommendation stands on its own and is unaffected by the resolution above.

## Also Surfacing (high-value findings that change planned work)

- **No tool anywhere measures macro-*emitted* code.** Every static analysis tool (Credo, `ex_dna`, Dialyzer) operates on `.ex`/`.exs` source text as authored, never on expanded macro output. This makes the renderer (`mix ash_commanded.dump`) the *precondition* for enforcing three of the eleven rewrite rules, not a nice-to-have. STACK.md separately found **no tool at all** for the "no double-handling" rule — state this plainly; it is enforced only by human code review.
- **Spark auto-prepends `VerifyEntityUniqueness` and `VerifySectionSingletonEntities`** to every extension (`extension.ex:459-461`) — this removes the need for some planned hand-written verifiers outright.
- **`{:behaviour, module}` / `{:spark_behaviour, ...}` do NOT verify behaviour implementation** — only `is_atom/1` is checked at the schema-type level; any "must implement X" requirement needs an explicit verifier.
- **`Commanded.Event.Upcaster` upcasts exactly once per event, never chained** — verified at `deps/commanded/lib/commanded/event/upcast.ex:15-21` and all five call sites. This is the single highest-value DSL design constraint found across all four documents.
- **The router defect's exact mechanism**: `composite_router.ex:75-87` runs `for command <- unquote(router_module).__registered_commands__()` **inside a `quote` block** — a compile-time loop requiring the router already compiled, confirmed directly against source, not inferred.
- **`Module.concat` from string surgery is invisible to the compiler's dependency-tracking mechanism** — the concrete, previously-unstated mechanism behind rewrite rule 4, which previously read as a style preference and is in fact a stale-BEAM correctness bug.
- **AshCommanded has zero `.Info` modules** (`find lib -iname '*info*'` returns nothing) despite "introspection belongs in `ModuleName.Info`" already being a stated rewrite rule — a complete gap, not a partial one, and should be treated as foundational work landing alongside the renderer.
- **Version correction, verified against `mix.exs`/`mix.lock`:** Spark resolves **2.7.2** (declared `~> 2.6`), Commanded resolves **1.4.11** (declared `~> 1.4`), Ash resolves **3.5.8**. `CLAUDE.md`'s "Spark 2.3.5 / Commanded 1.4.8 / Ash 3.5.9" is stale on all three axes. Any planning that assumes 2.3.5's Spark API is planning against a three-minor-version-old surface; e.g. `Ash.Domain.Info.depend_on_resources/1` — a macro older tutorials recommend for exactly this cross-module problem — is now `@deprecated`, "no longer necessary."
- **PITFALLS.md recommends Application and Routers be planned as ONE coupled unit.** Flag explicitly to whoever sequences the roadmap.

## Implications for Roadmap

### Phase: Foundation

**Rationale:** Every per-component "render and approve" step depends on the renderer existing first; several enforcement rules have literally no tool to check them until code is rendered to text.
**Delivers:** `mix ash_commanded.dump`, golden-file harness (hand-rolled), custom Credo checks, `ex_dna` adopted for DRY, `.Info` module convention established, `Spark.Test` used for verifier-error testing, shared `Module.create/3` wrapper with explicit `file:`/`line:`.
**Avoids:** Spurious warnings, lost caller environment, unintentional compile-dependency cascades.
**Research flag:** Standard pattern, low research risk during planning.

### Phase: Commands, Events, then Application

**Rationale:** Cheapest components, proves the render-and-approve methodology before it meets aggregates/routers.
**Delivers:** Commands/events unchanged in shape from today; Application component must resolve the router/application ordering defect using the now-settled domain-transformer mechanism.
**Research flag:** Standard pattern. The compile-order question that previously gated this is resolved.

### Phase: Aggregates and Projections

**Rationale:** Opens with the design question PROJECT.md itself poses: what is `AshCommanded.Aggregate.__using__/1`? Architecture research gives a complete, concrete answer.
**Addresses:** Rewrite rules 1, 2, 6, 9 directly.
**Research flag:** Standard pattern once the `__using__` design is fixed.

### Phase: Routers, Event Handlers, Process Managers

**Rationale:** Needs a domain transformer walking `Ash.Domain.Info.resources/1` and reading each resource's persisted state — the mechanism settled above.
**Delivers:** Three distinct generated shapes rather than one generic base.
**Research flag:** Plan jointly with Application, per PITFALLS.md's coupling recommendation.

### Phase: Declarative Event Versioning

**Rationale:** An ES library with no schema-evolution story is incomplete; the single-dispatch-per-event fact is a HIGH-recovery-cost correctness trap.
**Delivers:** A DSL composing intermediate transformations at generation time so each historical struct returns the current struct directly.
**Research flag:** Needs a replay-based acceptance test; API itself is fully understood.

### Phase: Snapshots, Middleware and Transaction Coordination

**Rationale:** Retarget fictional/unverified surfaces onto Commanded's real, documented internals.
**Delivers:** Snapshot config fragments (not an adapter behaviour); middleware verified against the real 3-callback contract.
**Research flag:** Standard pattern, HIGH confidence.

### Phase Ordering Rationale

- Foundation must precede everything.
- Commands/Events/Application-before-Aggregates matches the existing milestone plan.
- Aggregates and Routers are the hardest components and should get the most roadmap attention.
- Event versioning is sequenced to land before any real event data exists (i.e., before the deferred `core` migration).

### Research Flags

Standard patterns, low research risk: **Foundation**, **Commands**, **Events**, **Application**, **Aggregates**, **Routers/Event Handlers/Process Managers**, **Declarative Event Versioning**, **Snapshots/Middleware**.

No component now requires a pre-planning research spike.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (enforcement tooling) | MEDIUM-HIGH | HIGH for off-the-shelf tools; explicitly flagged where no tool exists at all |
| Features (Spark API reference) | HIGH | Every claim read directly from vendored source with file:line citations |
| Architecture | HIGH | Precedent-reading is HIGH; the disputed compile-order claim was resolved by experiment — conclusion confirmed, stated mechanism corrected |
| Pitfalls | HIGH | HIGH for all Commanded API claims; MEDIUM for restructuring guidance |

**Overall confidence:** HIGH.

### Gaps to Address

- **AshGraphQL/AshJsonApi's domain-aggregation approach was not independently source-verified** — cited for direction only, MEDIUM confidence.
- **`ex_dna`'s Elixir/OTP floor was not independently confirmed** — verify at `mix deps.get` time.
- **AshCommanded's own middleware modules' actual conformance to `@behaviour Commanded.Middleware` is unverified** — treat `CLAUDE.md` naming as unverified until confirmed.
- **No mechanical check exists for "no double-handling" (Rule 9)** — must be carried into the roadmap as an explicit code-review checklist item.
- **Compile deadlock risk** if a future design has resource-level transformers calling into their domain while domain transformers call back into resources — check explicitly before introducing any such bidirectional read.

## Sources

### Primary (HIGH confidence)

- `deps/spark` (hex 2.7.2, vendored) — `dsl.ex`, `dsl/extension.ex`, `dsl/transformer.ex`, `dsl/extension/entity_option.ex`, `dsl/entity.ex`, `dsl/section.ex`, `options/options.ex`, `info_generator.ex`, `cheat_sheet.ex`, `formatter.ex`, `test.ex`
- `deps/ash` (hex 3.5.8) — `domain/dsl.ex`, `resource/dsl.ex`, `domain/info.ex`, `domain/verifiers/validate_related_resource_inclusion.ex`
- `deps/commanded` (hex 1.4.11) — `commands/router.ex`, `commands/composite_router.ex`, `application.ex`, `event/handler.ex`, `event/upcaster.ex`, `event/upcast.ex`, `aggregates/aggregate.ex`, `aggregates/aggregate_lifespan.ex`, `snapshotting.ex`, `middleware/middleware.ex`, `assertions/event_assertions.ex`, `process_managers/process_manager.ex`
- Orchestrator compile-order probe, 2026-09-15 (`MIX_ENV=test mix compile --force`, three-file fixture, since removed)
- `work/core/deps/{ash_graphql,ash_authentication,ash_postgres,reactor}`
- `ash-project/ash_json_api`, `ash-project/ash_oban` (GitHub, `main`, fetched via `gh api`)
- `lucasvegi/Elixir-Code-Smells` catalogue (fetched 2026-09-15)
- Credo/Sourceror/ex_dna official docs and hexdocs

### Secondary (MEDIUM confidence)

- AshGraphQL/AshJsonApi's schema-assembly-time aggregation strategy — not source-verified in this repo's `deps/`
- `ex_dna`'s Elixir/OTP compatibility floor

### Tertiary (LOW confidence, do not adopt without re-verification)

- `approval`/`ApprovalTests.Elixir` maintenance status
- `assert_value_elixir` current release date

---
*Research completed: 2026-09-15*
*Compile-order question resolved experimentally 2026-09-15; no pre-planning spike outstanding*
