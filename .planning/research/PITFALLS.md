# Pitfalls Research: AshCommanded (Spark DSL + Commanded CQRS/ES) + `core` Migration

**Domain:** Spark DSL library generating Commanded (CQRS/Event Sourcing) modules for Ash Framework resources, plus migrating an existing production event-sourced Phoenix/Ash application (163 modules, ~6,398 LOC, 5 domains, live Postgres event store) onto it.
**Researched:** 2026-09-11
**Confidence:** HIGH for Commanded/Spark mechanics (verified against hexdocs, source code on GitHub, and this repo's own code). MEDIUM for migration-strategy judgment calls (12, 13) — these are engineering-risk assessments, not documented APIs, so treat the strategy as a recommendation, not a spec quote.

---

## Critical Pitfalls

### Pitfall 1: Event-type string is bound to the Elixir module name — renaming/moving an event module breaks deserialization of every historical event of that type

**What goes wrong:**
`core`'s Postgres event store has real rows whose `event_type` column holds strings like `"Elixir.Core.Identity.Events.OrganisationRegistered"`. If AshCommanded generates the equivalent event struct at any other module path (e.g. `MyApp.Identity.Events.OrganisationRegistered`, or even the same name under a different domain prefix), every historical row of that type becomes **undeserializable**. This is not a style concern — it is a hard runtime failure.

**Why it happens (traced through source, not inferred):**

- Commanded's default type provider is `Commanded.Serialization.ModuleNameTypeProvider`. Its `to_string/1` is exactly `Atom.to_string(struct.__struct__)` — the literal, fully-qualified module name becomes the serialized `event_type`, and `to_struct/1` is `type |> String.to_existing_atom() |> struct()`. ([`module_name_type_provider.ex`](https://github.com/commanded/commanded/blob/master/lib/commanded/serialization/module_name_type_provider.ex))
- `Commanded.Serialization.JsonSerializer.deserialize/2` calls `TypeProvider.to_struct(type)` to know which struct to decode JSON into. ([`json_serializer.ex`](https://github.com/commanded/commanded/blob/master/lib/commanded/serialization/json_serializer.ex))
- The Postgres adapter (`commanded_eventstore_adapter`)'s `Mapper` passes `event_type` straight through unchanged from what `Commanded.EventStore` already computed via `TypeProvider.to_string/1` before calling the adapter — it does not re-derive it. ([`mapper.ex`](https://github.com/commanded/commanded-eventstore-adapter/blob/master/lib/commanded/event_store/adapters/event_store/mapper.ex)) So this trap is identical whether `core` uses the in-memory adapter (tests) or the Postgres adapter (production) — the module-name coupling happens above the adapter layer, in Commanded core.
- `String.to_existing_atom/1` raises `ArgumentError` if the atom was never allocated at runtime — i.e., if the old module no longer exists anywhere in the compiled/loaded code. This is a **crash**, not silent data loss: aggregate rebuild-from-history, `assert_receive_event`, and any process manager/projector consuming that historical stream will blow up the instant it hits an old event whose type string no longer resolves to a loaded module.
- Confirmed in this repo: `AshCommanded.Commanded.Transformers.GenerateEventModules.build_event_module/2` computes the event module as `Module.concat([app_prefix, "Events", event_name_str])`, where `app_prefix` is derived from the **Ash resource's own module path** (its namespace minus the last segment, via `BaseTransformer.get_module_prefix/1`). There is no mechanism today to declare a serialized event-type string independent of this computed module path — `event_name` on the DSL only overrides the *last path segment*, not the type string used by the `TypeProvider`. `core` also has no custom `type_provider` configured, so it is fully exposed to this today.

**How to avoid:**
Two options, not mutually exclusive — pick per-domain based on how closely the DSL-computed path matches the legacy path:

1. **Byte-identical module paths.** Model the Ash resource so `BaseTransformer.get_module_prefix/1` reproduces the exact legacy namespace (e.g. resource lives at `Core.Identity.User`, DSL event named `:organisation_registered` → generates `Core.Identity.Events.OrganisationRegistered`, matching the hand-written module verbatim). This requires zero new code but is fragile: any deviation (different resource module location, different `"Events"` folder convention, pluralization difference) silently breaks it. Verify with a script that diffs `Module.split/1` of every generated event module against every legacy event module before cutover.
2. **Explicit `TypeProvider`, decoupled forever.** Implement `@behaviour Commanded.EventStore.TypeProvider` with a static map from legacy type strings to whatever module the DSL actually generates, and configure `config :commanded, type_provider: Core.EventTypeProvider`. This is strictly safer (removes the coupling permanently, survives any future refactor) and should be built as part of this project regardless of option 1, because it also gives the DSL a real answer to "what is the serialized name of this event" — currently it has none. Add a DSL option (e.g. `event_name`/`type_name`) that feeds this map, so authors can declare the legacy type string explicitly per event.

Recommendation: **build the explicit `TypeProvider` unconditionally.** Relying on path reconstruction (option 1) for 68 event modules across 5 domains, with zero tooling to catch a mismatch, is a guaranteed eventual production incident. The `TypeProvider` also becomes the natural mechanism for renaming events going forward without ever touching the event store again.

**Warning signs:**

- Any generated event module's fully-qualified name differs from the hand-written module it's replacing — check this with a diff script before any domain migration, not after.
- No `type_provider` configured in `core`'s `config.exs` for the `:commanded` app (confirmed absent today).
- Tests that only construct fresh events and never replay a *pre-existing* production-shaped event through the new modules — this hides the whole problem.

**Phase to address:**
This is project-defining and must be solved **before any domain migrates**, i.e., in the same phase as (or immediately before) the first `core` domain migration — not deferred to "polish." Building the `TypeProvider` abstraction should land as a Library Completion deliverable so every subsequent domain migration reuses it rather than reinventing per-domain path gymnastics.

---

### Pitfall 2: Transformer ordering bugs manifest as silent missing generation, not compile errors

**What goes wrong:**
A transformer that depends on state persisted by another transformer, but declares the wrong (or no) `before?`/`after?` relationship, runs before that state exists. Spark does not error on this by default — `Transformer.get_persisted/3` and `Transformer.get_entities/2` simply return `nil`/`[]`/defaults when queried too early, so the dependent transformer silently produces nothing (or the wrong thing) rather than raising.

**Why it happens:**
Spark's own docs describe the mechanism plainly: transformers declare relative ordering with `before?/1`/`after?/1` and "run in dependency order" — there is no built-in mechanism that surfaces "transformer X expected data that transformer Y hadn't produced yet" as an error; it just looks like "no data." ([Spark: Writing Extensions](https://spark.hexdocs.pm/writing-extensions.html)) This repo's transformers already rely on this: e.g. `GenerateEventModules.after?(GenerateCommandModules)`, `GenerateProjectorModules.after?(GenerateProjectionModules)` — each reads persisted state (`:event_modules`, `:projection_modules`) written by the transformer it depends on. Get one relationship wrong (or add a new transformer without wiring its `after?/before?`) and the dependent transformer runs against an empty list — no crash, just an incomplete generated module.

**How to avoid:**

- Every new transformer's `after?/1`/`before?/1` pair must be paired with a test that asserts the **specific persisted value** the transformer reads is non-empty and correct after full DSL compilation — not just that "the module exists" (see Pitfall 5).
- Prefer verifiers, not transformers, for anything that is validation-only. Spark's own guidance: "Prefer verifiers over transformers when you only need to validate — they run later, see the final state, and their post-compilation timing avoids circular compile-time dependencies." Only use a transformer when you must generate/mutate DSL state.
- Add an explicit ordering integration test: compile a resource with every section populated, then assert that every generated module (aggregate, event, command, projector, router) contains everything the DSL declared. This project's existing `test/commanded/verifiers/integration_test.exs` is the right *shape* — expand it to cover transformer output, not just verifier presence.

**Warning signs:**

- A generated module missing fields/functions correctly declared in the DSL, in a way that's obvious once you look for it but doesn't fail any test today.
- Adding a new transformer without updating any `after?`/`before?` callback.

**Phase to address:** Library Completion phase, alongside the testing-story work — this needs a systematic transformer-output integration test **before** absorbing `core`'s more complex projector/aggregate logic (which will add more transformers and more inter-dependencies).

---

### Pitfall 3: Compile-time introspection of sibling resources/domains deadlocks the compiler

**What goes wrong:**
Calling `Ash.Domain.Info.resources/1` (or any `Ash.Resource.Info.*` on a resource other than the one currently compiling) from inside a transformer can deadlock Elixir's parallel compiler, or fail with "module is not available" / undefined-function errors, depending on timing.

**Why it happens:**
A transformer runs while its own resource's module is *still being compiled* — the module doesn't exist as a callable entity yet. If it (directly or via a called function) then tries to invoke `Info` functions on **another** module that is itself still compiling (e.g., the Domain, which needs to enumerate `Resources` to build `GenerateCommandedApplication`'s router registration, while those Resources are simultaneously compiling and depending on the Domain being resolvable) you get a genuine circular compile-time dependency. Elixir's compiler detects mutual `@compile_time` dependencies and either deadlocks or raises. This is exactly the shape of problem the Domain/Resource DSL split (`fix-application-generation` branch) exists to solve: the Commanded *application* (one router, one event store, one supervisor) is a domain-level singleton that needs to know about every resource's generated command/event/aggregate modules — a natural place to reach for `Ash.Domain.Info.resources/1` inside a transformer, which is precisely the trap.

**How to avoid:**

- Never call `Ash.Domain.Info.*`/`Ash.Resource.Info.*` on another module from within a `Spark.Dsl.Transformer.transform/1`. If domain-level generation needs per-resource facts (e.g., "which resources have `commanded` sections, what are their generated aggregate module names"), have **each resource's own transformer persist that fact into its own DSL state** (already done here via `Transformer.persist(dsl_state, :event_modules, ...)` etc.), and have the **domain-level transformer read it via `Spark.Dsl.Extension.get_persisted/3` on the resource module only after that resource has fully compiled** — which in practice means doing this work in a **verifier** (post-compile, all modules loaded) rather than a transformer, or relying on `Ash.Domain`'s own compile-time resource list (which Ash itself manages through a different, already-resolved mechanism) rather than introspecting resources that may still be mid-compile.
- The existing code in this repo already works around part of this: `GenerateProjectorModules` reads `Transformer.get_persisted(dsl_state, :domain)` (the *atom*, persisted by Ash itself onto the resource, not a live call into the Domain module) specifically to avoid needing the Domain module to be compiled yet — that pattern (read a persisted atom/value, never call `Info` on a possibly-uncompiled module) is the one to generalize.

**Warning signs:**

- `(CompileError) module Foo is not loaded and could not be found` or a hang during `mix compile` that only appears when resources and domains reference each other.
- Any transformer code path that calls `Ash.Domain.Info` or `Ash.Resource.Info` on a module argument that isn't `Transformer.get_persisted(dsl_state, :module)` (i.e., not "self").

**Phase to address:** Must be resolved as part of finishing the Domain/Resource DSL split (already in flight on `fix-application-generation`) — this is the concrete failure mode that split needs to eliminate, and any projector-auto-discovery work (the `generate_commanded_application.ex:115` TODO) will reintroduce this exact risk if implemented as a naive cross-resource `Info` call inside a transformer instead of via persisted DSL state.

---

### Pitfall 4: Verifier gaps — DSL misconfiguration compiles cleanly and fails at runtime instead

**What goes wrong:**
Nine verifiers exist today, but several classes of misconfiguration have no verifier: e.g. a command whose name collides with an existing Ash action (`ValidateCommandNameConflict` is documented in `CLAUDE.md` but does not exist in `lib/commanded/verifiers/`), or a projection action that's valid but whose `changes` reference an attribute that doesn't exist on the *projection target*, not just the source resource. These compile fine and then fail — as a runtime `Ash.Error` or worse, a silently-wrong write — the first time a real event flows through.

**Why it happens:** Verifiers were added incrementally, ahead of and behind actual usage; the CLAUDE.md documentation of this repo is aspirational in places (three documented verifiers don't exist), which is itself evidence that "verifier coverage" has drifted from "verifier documentation" more than once already.

**How to avoid:**

- Build the verifier checklist directly from `core`'s real patterns (already an Active requirement: "Audit the library against `core`'s real event-sourcing patterns"). Every pattern `core` uses that has no corresponding verifier is a verifier to write before migrating that domain, not after.
- Every verifier must ship with **both** a positive test (valid DSL compiles) and a **rejection test** (invalid DSL raises `Spark.Error.DslError` with a specific, asserted message) — see Pitfall 5 for the exact pattern. A verifier with no rejection test is unverified.
- Treat `ValidateCommandNameConflict` as a concrete gap to close, not a documentation error to quietly delete — it exists because command dispatch and Ash action dispatch can be invoked through similar-looking paths, and a name collision is a real production incident (data mutated through the wrong path), not a hypothetical.

**Warning signs:** Any DSL option/section that has no verifier at all covering "what if this is wrong" — audit by listing every `Spark.Dsl.Entity` schema field this library defines, and confirming a verifier constrains its cross-references.

**Phase to address:** Library Completion phase, specifically the "produce an explicit capability checklist" Active requirement — verifier gap-closing should be driven by that checklist, in the same phase, before migration starts (a verifier gap found *during* migration of a live domain is a much more expensive place to discover it).

---

### Pitfall 5: "Contrived tests" — asserting a module exists is not asserting the DSL works, and this repo already ships this defect

**What goes wrong:**
`test/commanded/verifiers/event_handler_tests.exs` asserts only that verifier *modules* load and implement `Spark.Dsl.Verifier` — it never compiles a bad DSL and checks it's rejected. More subtly and more dangerously: **four transformers in this codebase skip actual module creation by default whenever `Mix.env() == :test`** — `generate_aggregate_module.ex`, `generate_main_router_module.ex`, `generate_event_handler_modules.ex`, and `generate_projector_modules.ex` all gate `BaseTransformer.create_module/3` behind `Application.get_env(:ash_commanded, :skip_*_module_creation, Mix.env() == :test)`. This means most of the test suite, by default, is exercising the DSL-parsing and entity-building logic but **never actually generates the aggregate, router, event-handler, or projector module it appears to be testing** unless a test explicitly opts back in via config. Any test that then does `assert Code.ensure_loaded?(GeneratedModule)` in the default test environment is either not testing what it claims, or (worse) is compiling a module that then leaks into a *shared* test-env application config for the rest of the suite.

**Why it happens:** The `skip_*_module_creation` flags were almost certainly added to keep `mix test` fast/side-effect-free (dynamically defining and loading dozens of modules per test run is real compile cost and creates global-atom-table growth), but the trade-off — tests silently not exercising code generation — was never made explicit or paired with a parallel "and here's how you test the real generated output" story. This is exactly the gap the project's requirements call out: "no documented testing story."

**How to avoid — concrete, working patterns:**

**1. Testing that a bad DSL is rejected at compile time** (the verified, load-bearing pattern — taken directly from `ash-project/ash`'s own test suite, e.g. `test/policy/simple_test.exs` and `test/resource/identities_test.exs`):

```elixir
test "duplicate command names are rejected" do
  assert_raise Spark.Error.DslError, ~r/command name .* is already in use/, fn ->
    defmodule DuplicateCommandResource do
      use Ash.Resource,
        domain: nil,
        extensions: [AshCommanded.Commanded.Dsl]

      attributes do
        uuid_primary_key :id
      end

      commanded do
        commands do
          command :register_user do
            fields([:id])
          end

          command :register_user do
            fields([:id])
          end
        end
      end
    end
  end
end
```

This works because `defmodule` inside the anonymous function body is only evaluated (and therefore only triggers transformer/verifier execution) **when the test runs**, not when the test file itself compiles — so `assert_raise` genuinely wraps and catches the `Spark.Error.DslError` raised from within `__verify_spark_dsl__` / `__after_compile__`. This is the identical pattern Ash's own test suite uses throughout (`ash-project/ash:test/resource/policies_test.exs`, `test/domain/domain_test.exs`, `test/type/union_test.exs`) — it is a proven pattern, not a guess.

Two things to get right or the pattern breaks:

- **Use a fresh, uniquely-named module per test** (e.g. `Module.concat(["Test#{System.unique_integer([:positive])}", DuplicateCommandResource])` inside a `defmacrop`, as `ash-project/ash` does in `identities_test.exs`) when tests run `async: true` — Elixir's module namespace is global per-VM, so two tests defining `DuplicateCommandResource` in the same test run (even sequentially, if one fails before cleanup) will collide with a "redefining module" warning or, worse, silently reuse stale compiled state.
- **Assert on the error message with a regex**, not just the exception type — `Spark.Error.DslError` is generic; without a message assertion, the test would pass even if a *different, wrong* validation failure fired for the wrong reason.

**2. Testing transformer output (not just "module exists"):**

```elixir
test "generates a command struct with the declared fields and typespec" do
  defmodule CommandOutputResource do
    use Ash.Resource, domain: nil, extensions: [AshCommanded.Commanded.Dsl]
    attributes do
      uuid_primary_key :id
      attribute :email, :string
    end
    commanded do
      commands do
        command :register_user do
          fields([:id, :email])
          identity_field(:id)
        end
      end
    end
  end

  # Must NOT rely on the default :skip_aggregate_module_creation/etc test config —
  # explicitly force generation for this test, then clean up.
  generated = AshCommanded.Commanded.CommandOutputResource.Commands.RegisterUser
  assert Code.ensure_loaded?(generated)
  assert generated.__struct__() |> Map.keys() -- [:__struct__] |> Enum.sort() == [:email, :id]
  # Exercise the struct as data, not just its existence:
  cmd = struct(generated, id: "abc", email: "a@b.com")
  assert cmd.email == "a@b.com"
end
```

The key discipline: **construct and use the generated struct/module as a value** (build a struct, call a generated function, pattern-match a generated clause) — never stop at `Code.ensure_loaded?/1`, which only proves the atom resolves to *some* loaded module, not that it has the shape the DSL declared.

**3. Testing generated-module *behaviour* (aggregate execute/apply round trip)** — build a real given/when/then test using Commanded's own recommended shape (see Pitfall 9/10): dispatch a command through the router, assert the resulting event via `Commanded.Assertions.EventAssertions.assert_receive_event/4`, then dispatch a second command and assert the aggregate's *apply* logic produced the right state transition — this is the only test that actually proves `GenerateAggregateModule`'s execute/apply pairing works, as opposed to merely existing.

**Warning signs:**

- Any test whose only assertion is `Code.ensure_loaded?/1`, `Spark.implements_behaviour?/2`, or `assert length(entities) == N` with no assertion on the *content* of what those entities produced downstream.
- `Application.get_env(:ash_commanded, :skip_*_module_creation, ...)` left at its default in a test that appears to test generated-module behaviour.

**Phase to address:** This is the concrete deliverable behind "Tests that exercise unhappy paths" and "documented testing story" in Active requirements — should be one of the first things done, because every subsequent phase (event versioning, aggregate invariants, migration) needs this pattern to test its own additions honestly, not build more contrived tests on top of a shaky foundation.

---

### Pitfall 6: Getting event upcasting wrong on a store with existing events is not always recoverable

**What goes wrong:**
`Commanded.Event.Upcaster.upcast/2` runs at read time, transforming an event **after** deserialization and **before** it reaches an aggregate/handler/process manager. `core` already depends on this (e.g. `OrganisationRegistered` drops removed fields on replay). Two distinct failure modes:

1. **Upcaster never runs at all** because the upcast target doesn't implement the protocol for the *actual* struct shape stored (e.g., you rename a field in the event module and forget the upcaster clause for the old shape) — old events replay with the new field as `nil`, silently, because Elixir structs default missing keys rather than erroring. This corrupts aggregate state on rebuild without ever raising.
2. **Upcaster raises or mismatches** because event serialization only reliably preserves strings, numbers, and booleans — "any other value will be converted to a string" ([Commanded events guide](https://commanded.hexdocs.pm/events.html)). An upcaster written assuming e.g. an atom or a `DateTime` struct survives serialization intact will get a string instead, and pattern-matching on the wrong shape either crashes or (worse) silently produces wrong data that then gets projected.

**Recoverability:** If the upcaster is *wrong* but the underlying event store is untouched (append-only, nothing overwritten), this is recoverable — because the raw stored data never changes, only the read-time transformation is wrong. Fix the upcaster, and any process that rebuilds state from history (aggregate hydration, a from-scratch projection rebuild) will get the corrected result on next read. **What is not recoverable**: if a wrong upcast result was fed into a **new write** (e.g., a corrected/upcasted event value was written back as a *new* event, or a snapshot was taken of the corrupted state and that snapshot is what's replayed going forward) — at that point the corruption is baked into the append-only log itself and requires either a compensating event or manual data surgery.

**Why it happens:** Upcasting is easy to reason about for "add a field with a default" and easy to get subtly wrong for "remove a field," "rename a field," or "split one event into two" — especially combined with the string-only serialization guarantee, which most examples in blog posts gloss over.

**How to avoid:**

- Never mutate history to "fix" an upcast bug. Always fix the upcaster and re-derive; if a snapshot store is involved (as it is here — ETS-backed, per `CONCERNS.md`), **invalidate/delete snapshots** whenever the upcast logic changes, since a stale snapshot bypasses the upcaster entirely for everything before the snapshot point. (This repo's existing gap — "No Snapshot Version Migration Strategy" — is directly relevant: a snapshot taken before an upcaster fix will never re-run that upcaster on rehydration unless snapshots are explicitly invalidated.)
- Write upcasters defensively against the string-degradation behavior: expect metadata/fields that were atoms, dates, or numbers-as-strings to arrive as plain strings; use explicit parsing (`String.to_existing_atom/1` guarded, `DateTime.from_iso8601/1`), never a bare pattern match on the "original" type.
- The DSL should make declaring an upcaster a first-class, verifiable construct (Active requirement: "Declarative event versioning") — specifically so a verifier can catch the common mistake of adding a new required field to an event without a corresponding upcast clause for the old shape, at compile time rather than at first replay.

**Warning signs:** Any event struct change (add/remove/rename field) in a resource with events already in `core`'s production store, made without a corresponding `Upcaster` clause and without a test that constructs the *old* serialized shape and asserts the upcast result.

**Phase to address:** This must be solved as a DSL capability (declarative upcasting) before migrating any domain whose events have already changed shape historically — per `CONCERNS.md`, `core`'s `identity` domain already relies on this, so `identity`'s migration is blocked on this capability existing and being tested against a **real captured historical event payload**, not a freshly-constructed one.

---

### Pitfall 7: Projectors must tolerate at-least-once redelivery — and this codebase's generated projectors currently have no idempotency mechanism at all

**What goes wrong:**
Commanded event handlers (which is what `GenerateProjectorModules` generates today — plain `use Commanded.Event.Handler`, not `Commanded.Projections.Ecto`) are guaranteed **at-least-once** delivery: on handler crash, application restart, or handler-restart-from-error, the same event can be delivered again. `Commanded.Projections.Ecto` exists specifically to solve this — it maintains a `projection_versions` table and wraps the projection in a DB transaction with an idempotency check, "needed because Commanded event handlers guarantee at-least-once event delivery" ([`commanded_ecto_projections` docs](https://hexdocs.pm/commanded_ecto_projections/Commanded.Projections.Ecto.html)). **This repo's generated projector does not use that macro** — it calls `Ash.create`/`Ash.update`/`Ash.destroy` directly from a bare `Commanded.Event.Handler.handle/2` clause with no idempotency guard. Re-delivery of a `:create` event after a crash mid-projection will raise a unique-constraint error (if lucky) or double-apply an `:update` (if not).

**Why it happens:** The generated projector was built to demonstrate the shape (event → projection → Ash action) without wiring in Commanded's own idempotency primitive, and nothing in the test suite currently exercises redelivery (there is no "dispatch the same event twice and assert the projection only applied once" test anywhere in the current suite).

**How to avoid:**

- Every generated Ash-backed projection must become idempotent by construction. Two workable strategies, either acceptable:
  1. Have the projector record the last-processed `event_number` per aggregate stream (mirroring what `Commanded.Projections.Ecto`'s `projection_versions` table does) and skip re-application when the incoming event's `event_number` is not greater than what's recorded, inside the same Ash transaction that performs the create/update — this requires the projection's own resource to carry a "last projected event number" or an idempotency key, and the projector to check-then-write atomically.
  2. Make the Ash actions themselves idempotent at the domain level — `:create` actions become `:create` with `upsert?: true` on the natural key, `:update` actions become "set to the values in this event" (absolute, not relative, deltas) so replaying the same event twice is a no-op. This is often the simpler fix and matches how `core`'s existing hand-written projectors likely already behave (worth auditing during the capability-checklist pass) — but it must be verified per-projection, not assumed.
- Add exactly one integration test per generated projector: dispatch the same event to the handler function twice in a row (not through the full router — call `handle/2` directly with the same event struct) and assert the resulting read-model row is identical after either delivery.

**Warning signs:** Any generated projector whose Ash action is a plain `:create` (no upsert) fed directly by event data with no dedup key, or an `:update` that computes a delta (`increment`, `append`) rather than setting an absolute value.

**Phase to address:** Library Completion — this belongs in the "Projection expressiveness" line item, and must be closed **before** migrating `data`/`workflow` (per `CONCERNS.md`, projectors are "the heaviest category" at 3,523 LOC — real logic, likely including exactly this kind of delta-update that's currently vulnerable).

---

### Pitfall 8: `:eventual` vs `:strong` dispatch consistency, and the classic read-your-own-write bug in web handlers

**What goes wrong:**
Commanded event handlers process persisted events **asynchronously** by default. Dispatching a command with the default `consistency: :eventual` returns `:ok` as soon as the command is handled and events are persisted — **before** any projector has necessarily updated the read model. A LiveView `handle_event`/Phoenix controller action that dispatches a command and then immediately queries the projection (e.g., to render the just-created record, or to redirect to its show page) will intermittently get stale data — "intermittently" because it depends on projector processing latency, which is exactly the kind of bug that passes locally (in-memory adapter, fast) and flakes in staging/production (Postgres adapter, slower, under load).

**Why it happens:** `consistency: :strong` exists precisely to prevent this — dispatching with `consistency: :strong` "will block until all events created by the command have been processed by the handlers that opt-in to use strong consistency," guaranteeing the read model is queryable immediately after `:ok` ([Commanded FAQ / consistency docs](https://github.com/commanded/commanded/wiki/FAQ)) — but it must be opted into **both** at dispatch time and by the specific handler (handlers declare `consistency: :strong` in their `use Commanded.Event.Handler` options to be eligible), and it is easy to add a new projector without remembering to make this decision explicitly, defaulting silently to `:eventual`.

**How to avoid:**

- Every generated projector must have an explicit, DSL-declared consistency setting (not an unstated default) — surface it as a required or defaulted-with-warning DSL option, so authors of new projections in `core` make the read-your-own-writes decision consciously rather than discovering it as a support ticket.
- Any web-facing flow that dispatches a command and then reads the projection in the same request/LiveView event **must** dispatch with `consistency: :strong` for the specific projector(s) that flow depends on, or must be redesigned to not require immediate read-after-write (e.g., render from the command's own returned data / an optimistic view, not a re-query).
- Document this trade-off explicitly (latency vs. staleness) as part of the projection DSL docs — the "Documented testing story" Active requirement should include a test pattern that demonstrates the flaky-without-strong-consistency failure mode directly, so it's caught in review rather than in production.

**Warning signs:** Any controller/LiveView code path with `dispatch(command)` immediately followed by a query against a resource populated by an async projector, with no `consistency: :strong` and no test that dispatches-then-immediately-reads (a test using the in-memory adapter may pass even when this bug is live, because in-memory processing can be fast enough to race-win in test but not in production — do not trust a green test here without an explicit consistency assertion).

**Phase to address:** Should be decided and documented during the projection-expressiveness Library Completion work, then explicitly checked per-projection during each domain migration (a per-domain migration checklist item: "does any caller read-after-write on this projection? if so, is consistency: :strong set?").

---

### Pitfall 9: Aggregate design errors — oversized aggregates, wrong invariant boundaries, using the read model to make write decisions

**What goes wrong:**
Three related mistakes recur in Commanded systems, and `core`'s own aggregates (1,822 LOC across 13 files, "genuine invariants mixed with dispatch plumbing" per `PROJECT.md`) already show signs of at least the first two:

1. **Oversized aggregates** — modeling an entire bounded-context entity (with all its associations) as one aggregate/stream instead of splitting along true transactional-consistency boundaries. Every command against that entity serializes through one Commanded aggregate process, which both limits throughput and forces unrelated invariants into one module.
2. **Wrong invariant boundaries** — deciding business rules (e.g. `status: :suspended` → reject update) inside the aggregate is correct; the risk is when equivalent decisions are *also* made from a **read model/projection** during command validation (e.g., checking a projected/denormalized table to decide whether a command is allowed) instead of from the aggregate's own rehydrated state, which is guaranteed consistent at the moment of decision. Read models are eventually consistent by construction (Pitfall 8) — using one to gate a write reintroduces exactly the race the aggregate pattern exists to prevent.
3. **Non-attribute aggregate state** — `core`'s aggregates already hold state that isn't an Ash resource attribute (e.g. `members: %{}`), which `GenerateAggregateModule` today has no vocabulary for (a documented gap in `PROJECT.md`). Bolting this on naively risks re-mixing plumbing and invariants right back together, undoing the value of the DSL.

**Why it happens:** Aggregates are usually first modeled around the domain object (User, Organisation) rather than around the *consistency boundary actually required by the business rule* — the two often coincide for simple CRUD-shaped entities and diverge exactly where the real invariants live (which is why `core`'s aggregate code, not its command/event structs, is where the "genuine invariants" concentrate).

**How to avoid:**

- Before migrating each domain, explicitly enumerate: what commands must be rejected based on *current aggregate state* (not the read model)? Anything answered "we check the projection for that" is a design smell to fix during migration, not preserve.
- The DSL's aggregate-invariant feature (Active requirement) should let authors declare "reject this command when aggregate state matches X" directly, so the invariant is visible in the DSL rather than buried in generated `execute/2` clause ordering — this also makes it verifiable/testable in isolation from dispatch plumbing.
- For non-attribute state (`members: %{}` etc.), design the DSL feature so aggregate state is explicitly a superset of resource attributes (declared separately, not inferred from the Ash resource schema) rather than trying to stretch Ash attributes to cover it — conflating the two will recreate the invariant-vs-plumbing mixing problem this project explicitly wants to remove.

**Warning signs:** Any command handler/aggregate `execute/2` clause that queries a projection/read-model resource (via `Ash.read`) rather than deciding purely from the aggregate struct passed in.

**Phase to address:** Aggregate-invariant and non-attribute-state DSL features (Library Completion) must ship before migrating `identity` (documented as holding this exact pattern) — migrating that domain without this capability forces either an escape hatch that reintroduces hand-written plumbing, or an incorrect simplification of the actual business rule.

---

### Pitfall 10: Test isolation failures unique to event-sourced systems — event store state leaking across tests, and in-memory-vs-Postgres behavioural drift

**What goes wrong:**
Two distinct classes of test-isolation bug are specific to this domain (beyond ordinary test-isolation hygiene):

1. **Event store state persists across tests** unless explicitly reset — Commanded's own guidance is to restart the *entire application* between tests (not just clear a table), because "your app must be stopped and then started between resetting the event store... to ensure all application processes are restarted with their initial state to prevent state from one test affecting another" ([Commanded Testing guide](https://commanded.hexdocs.pm/testing.html)). A naive `async: true` test suite that dispatches commands against a shared Commanded application (as would happen if tests just reuse the app started once for the whole run) will see aggregates, routers, and process managers retain state — and prior in-memory events — across supposedly-independent tests, producing order-dependent flakiness (a test passes alone, fails in the full suite).
2. **In-memory adapter and Postgres adapter are not behaviourally identical** — the in-memory adapter has no real transaction boundaries, no real serialization round-trip (it may keep structs as-is rather than JSON-encoding/decoding them — meaning a serialization/upcasting bug can be entirely invisible in a fast in-memory-adapter test suite and only surface against the real Postgres-backed event store), and different latency characteristics that mask consistency bugs (Pitfall 8's flaky-in-prod-only failure mode). Relying solely on the in-memory adapter for CI, while attractive for speed, systematically under-tests exactly the two riskiest areas of this project: upcasting/serialization (Pitfall 6) and dispatch consistency (Pitfall 8).

**Why it happens:** `async: true` is the default ExUnit posture and feels "free" until a shared external resource (event store, aggregate supervisor) is involved; the in-memory adapter is the natural first choice for CI speed and its behavioural gaps are non-obvious until something that depends on real serialization or real latency breaks.

**How to avoid:**

- Use an `ExUnit.CaseTemplate` that restarts the Commanded application (`Application.stop/1` + `Application.ensure_all_started/1`) around each test that touches the event store, and run these tests **non-async** — this is the pattern Commanded's own docs recommend, and it should be a shared test-support module in this library (not something every consumer, including `core`, reinvents).
- Maintain the two example applications called for in Active requirements (in-memory for fast CI + docs, Postgres for the real path) specifically so upcasting and consistency behaviour get tested against the adapter `core` actually runs — don't let the in-memory adapter's speed become the only CI signal for those two pitfall classes.
- For `core`'s own migration validation, run the *migrated* domain's test suite against a real (or `eventstore`-library-backed local) Postgres event store, not just in-memory, before considering that domain done.

**Warning signs:** Tests passing in isolation (`mix test test/some_test.exs`) but failing in the full suite (`mix test`) — classic shared-event-store-state symptom. Any assertion about upcasting or serialization edge cases (Pitfall 6) that only ever runs against the in-memory adapter.

**Phase to address:** The shared test-support module (application-restart case template) is part of "Documented testing story" (Library Completion); the dual in-memory/Postgres example apps are already a planned Active requirement — sequence them so the Postgres example exists **before** the first `core` domain migration is validated, since that migration's correctness claims are only as strong as the adapter they're tested against.

---

### Pitfall 11: See "Event-type string is bound to the Elixir module name" (Pitfall 1, above) — restated here to flag its migration-strategy consequences

*(Numbered separately in the brief; folded into Pitfall 1 above because it is the same root cause. The migration-strategy consequence, stated plainly per the downstream consumer's request: this is not a "nice to have decoupling" — it is a hard blocker. No domain in `core` can migrate its event-sourced code onto AshCommanded-generated modules until either (a) the generated module paths are verified byte-identical to the legacy ones for every event type in that domain, or (b) a custom `TypeProvider` is built and configured mapping legacy type strings to the new modules. The roadmap must include this as an explicit, gating deliverable — not an assumption folded into "migrate `identity`" — because it is the one mistake in this entire project that is expensive-to-impossible to reverse once made (once new events have been written under the new module path without a `TypeProvider` bridging the old ones, un-mixing the two type-string schemes in a live append-only log is a data-migration project in its own right).*

---

### Pitfall 12: Incremental migration — hand-written and DSL-generated aggregates can coexist in one router, but never for the same stream

**What goes wrong:**
The natural incremental strategy — migrate one `core` domain at a time, leaving the other four on hand-written Commanded modules — is sound **at the router level**: Commanded's router dispatches by command-struct-module to a registered aggregate module + identity field; there is nothing that requires all aggregates on a router to be either all hand-written or all DSL-generated. The danger is a narrower, easy-to-miss case: **migrating a domain "one aggregate at a time" while another aggregate in the same domain still references the old event/command modules directly** (e.g., a process manager or projector in an *unmigrated* domain pattern-matches on `%Core.Identity.Events.OrganisationRegistered{}` structs from the old module, while `identity`'s aggregate now emits the DSL-generated struct at a different path) — this silently breaks cross-domain event handlers even though each domain's own migration "looks" complete in isolation.

**How to avoid:**

- Treat "migrate domain X" as **atomic per event-emitting aggregate stream**, including every consumer of that stream's events (projectors, process managers, other domains' event handlers) — not atomic per file or per module. Before migrating a domain, grep every other domain for `alias`/pattern-matches against that domain's event modules, and cut them all over together (or, if Pitfall 1's `TypeProvider` is built first, this becomes moot for *serialization*, but in-process pattern matches on the struct's module still need updating everywhere they occur).
- Never run the old hand-written aggregate module and a new DSL-generated aggregate module registered against the **same stream/identity** simultaneously — pick one code path per aggregate type per deploy. A brief dual-write/dual-read period (both old and new code loaded, feature-flagged) is fine only if exactly one of them is ever the one actually receiving dispatch for a given aggregate instance at a time.
- Because all five domains are in scope for this project (per `PROJECT.md`'s explicit decision against a partial migration), sequence domains by **cross-domain event-consumption dependency** (migrate consumers before or together with the producers they depend on, or vice versa in one atomic cutover) rather than by convenience/size.

**Warning signs:** Any domain event handler/process manager that pattern-matches on another domain's *old* event module after that other domain has been "migrated."

**Phase to address:** Per-domain migration phases must each include an explicit cross-domain consumer audit as an exit criterion, not just "this domain's own tests pass."

---

### Pitfall 13: Verifying a migration is behaviour-preserving requires characterization tests against real historical data, not fresh unit tests

**What goes wrong:**
The tempting (and insufficient) way to validate a migrated aggregate/projector is to write new unit tests against the DSL-generated version and confirm they pass — but that only proves the new code satisfies *newly written expectations*, which is exactly what could be subtly wrong if the hand-written original encoded a nuance the migration missed (an edge case in a guard clause, an off-by-one in a projection, an upcaster branch for a rarely-hit legacy shape).

**What a credible before/after equivalence test looks like:**

1. **Characterize the hand-written original first, before touching it.** For each aggregate: capture a representative set of real event sequences from `core`'s actual event store for that stream type (a snapshot of production/staging event history, anonymized as needed), replay them through the **current hand-written aggregate**, and record the resulting state after each command in the sequence (a "golden" state trace). For each projector: capture real events, run them through the **current hand-written projector**, and record the resulting read-model rows.
2. **Replay the identical event sequences through the DSL-generated aggregate/projector** (post-migration, in a throwaway environment) and assert the resulting state/rows are identical to the golden trace, field for field.
3. **Explicitly include the "boring" historical events that predate the most recent schema version** — this is where upcasting equivalence actually gets tested (Pitfall 6); a characterization test built only from recent, current-shape events will never touch the upcaster's older branches at all.
4. **For projectors, additionally replay each event twice** (Pitfall 7) and confirm the golden-trace equivalence still holds after redelivery, since the hand-written original may have accidental idempotency (e.g., because it happened to use an upsert) that a naive DSL-generated version does not preserve unless explicitly designed for it.

This is the only way to catch "the generated version technically satisfies its own new tests but silently drops a rule the original encoded" — the actual risk in play is not "did we write the DSL correctly" but "did we correctly *read* every rule out of 1,822 lines of hand-written aggregate code and 3,523 lines of projector code," which is a transcription-fidelity problem, not a unit-testing problem.

**Warning signs:** A migration PR whose only tests are new tests written against the new code, with no reference to what the old code actually did for the same inputs.

**Phase to address:** Each per-domain migration phase's plan must include, as a named step preceding the cutover, extracting a golden trace from the domain's real event history and running it through both implementations — this should be tooling built once (a small "replay N events through aggregate/projector X, dump resulting state" harness) and reused for every domain, not re-invented per domain.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
| ---------- | -------------------- | ----------------- | ------------------ |
| Skip module creation in test env by default (`skip_*_module_creation`) | Fast, side-effect-free `mix test` | Tests silently stop exercising generated code; false confidence (Pitfall 5) | Never as the *only* mode — fine as an opt-in fast-path alongside an explicit "real generation" test tier |
| Rely on module-path reconstruction instead of an explicit `TypeProvider` (Pitfall 1) | Zero new code | Guaranteed eventual production incident on any path mismatch, no error surfaced until replay | Never for `core`'s migration — the store already has real data |
| Plain `Commanded.Event.Handler` projectors with no idempotency (Pitfall 7) | Simpler generated code, matches the README's documented example | Duplicate/failed writes on any redelivery, which *will* happen under normal operation (crash/restart) | Never for anything migrating from `core` — acceptable only for a toy/demo projection with disposable data |
| In-memory-only CI (no Postgres-adapter test tier) | Fast CI | Hides serialization/upcasting and consistency-latency bugs (Pitfall 6, 8, 10) | Acceptable for pure DSL-parsing/verifier unit tests; never acceptable as the sole coverage for anything event-store-facing |
| Default `:eventual` consistency with no DSL-level opt to `:strong` | Less DSL surface to design | Read-your-own-write bugs that are invisible in fast test environments (Pitfall 8) | Acceptable only if every consumer of a given projection is documented as tolerant of staleness |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
| ------------- | ----------------- | ------------------- |
| Commanded `EventStore` (Postgres adapter) | Assuming `event_type` is an implementation detail safe to ignore during refactors | Treat `event_type` as a public, versioned contract — see Pitfall 1 |
| `Commanded.Event.Upcaster` | Writing upcasters assuming original Elixir types (atoms, dates) survive serialization | Assume string-only survival for anything beyond string/number/boolean (Pitfall 6) |
| `Commanded.Projections.Ecto` (not currently used by generated projectors) | Assuming a hand-rolled `Ash.create`/`Ash.update` call is "close enough" to what the macro provides | Either adopt the macro's idempotency pattern explicitly, or build the equivalent (upsert / event-number check) — do not ship without one (Pitfall 7) |
| Ash `Domain`/`Resource` compile-time introspection from Spark transformers | Calling `Ash.Domain.Info.resources/1` (or resource `Info`) on a module that may still be compiling | Read only persisted DSL state on `self`, defer cross-module facts to verifiers (Pitfall 3) |
| Spark transformer ordering | Adding a new transformer without wiring `before?/1`/`after?/1` against every transformer it actually depends on | Every new transformer needs an explicit ordering test asserting the specific data it depends on is present (Pitfall 2) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
| ------ | ---------- | ------------ | ----------------- |
| Oversized aggregate/stream (Pitfall 9) | One aggregate process becomes a dispatch bottleneck; commands queue behind it | Split along true consistency boundaries during migration, not convenience boundaries | Noticeable once concurrent command volume against one entity exceeds what a single GenServer-backed aggregate process can serialize |
| ETS-only snapshot store (existing `CONCERNS.md` item) | Snapshots vanish on every deploy; aggregate rehydration falls back to full replay, getting slower as streams grow | Pluggable/persistent snapshot backend before migrating any high-event-count aggregate | Breaks the moment a long-lived aggregate's replay time (post-restart, no snapshot) exceeds acceptable command latency |
| `:strong` consistency dispatch used blanket, "to be safe" | Every command now waits on every projector, killing dispatch latency | Use `:strong` only for the specific projector(s) a given caller actually reads-after-write | Breaks under load as soon as `:strong` is applied more broadly than the actual read-your-write requirement |

## Security Mistakes

| Mistake | Risk | Prevention |
| --------- | ------ | ------------ |
| Command name collision with an existing Ash action (no `ValidateCommandNameConflict` verifier today) | A command could be dispatched down the wrong path, or an action invoked without going through command-handler validation/authorization middleware | Implement and test the missing verifier before it's needed by a real domain (Pitfall 4) |
| Middleware pipeline is optional and per-command (existing `CONCERNS.md` item) | A command dispatched without the validation/authorization middleware wired in bypasses checks silently | Default to strict middleware application; make omission an explicit, visible DSL choice, not a silent default |
| Generated command structs have no independent validation (existing `CONCERNS.md` item) | If middleware is misconfigured or bypassed, invalid/unauthorized data reaches the aggregate | Add a compile-time or verifier-level check that a command has at least a validation step configured, or an explicit opt-out |

## "Looks Done But Isn't" Checklist

- [ ] **A passing verifier test suite:** confirm each verifier test includes a genuine rejection case with a message assertion (`assert_raise Spark.Error.DslError, ~r/.../`) — not just "module loads and implements the behaviour" (Pitfall 5).
- [ ] **A passing transformer test suite:** confirm tests exercise `Mix.env() == :test` behavior explicitly and either force real module generation (`Application.put_env(:ash_commanded, :skip_*_module_creation, false)`) or explicitly document why existence-only assertion is sufficient for that specific test.
- [ ] **"Migrated" domain:** confirm every *other* domain's event handlers/process managers that reference this domain's event modules have also been updated (Pitfall 12) — a domain can look migrated in isolation while breaking a cross-domain consumer.
- [ ] **A projector "working" in dev/staging:** confirm it has been tested against redelivery of the same event (Pitfall 7), not just single delivery.
- [ ] **An upcaster "working":** confirm it has been run against a real captured historical event payload of the old shape, not only a freshly constructed one shaped by the developer's current mental model of "the old shape" (Pitfall 6, 13).
- [ ] **Event-store compatibility "handled":** confirm there is an automated check (script or test) diffing every generated event module's `Module.split/1` (or `TypeProvider` mapping) against the legacy event module it replaces — not a one-time manual eyeball during initial migration (Pitfall 1).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
| --------- | ---------------- | ------------------ |
| Event-type mismatch discovered post-migration, before new writes under the new path | LOW | Add/fix the `TypeProvider` mapping; no data was lost, only temporarily undeserializable |
| Event-type mismatch discovered after new events have already been written under the new (wrong) path | HIGH | Requires a one-time data migration pass rewriting/backfilling `event_type` values in the store (or a `TypeProvider` that maps *both* old and new strings to the same module going forward) — must be done carefully against an append-only store, ideally via the event store's own migration tooling, with a full backup first |
| Bad upcaster shipped and already read (but not re-written) | LOW–MEDIUM | Fix the upcaster; invalidate any snapshots taken while the bad upcaster was active so replay re-derives correctly (Pitfall 6) |
| Bad upcaster's wrong output was itself persisted as new events or baked into a surviving snapshot | HIGH | Requires compensating events or manual snapshot/event surgery — treat as a production incident, not a bug fix |
| Projector double-applied a redelivered event before idempotency was added | MEDIUM | Rebuild the affected read model from scratch by replaying the full event stream through a corrected, idempotent projector (this is exactly why projections should always be treated as disposable/rebuildable from the log — confirm this is true for every `core` projection before migrating it) |
| Transformer ordering bug silently produced incomplete generated modules already shipped | MEDIUM | Fix ordering, force full regeneration (recompile), and re-run the transformer-output integration tests (Pitfall 2) — no data recovery needed since this affects code generation, not the event store, provided it's caught before any behavior-dependent write went out |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
| --------- | -------------------- | ---------------- |
| 1/11: Event-type string bound to module name | Library Completion — build explicit `TypeProvider` support; gates every per-domain migration phase | Automated diff of generated vs. legacy event module paths/type strings, per domain, before cutover |
| 2: Transformer ordering silent failures | Library Completion — transformer-output integration tests | Full-DSL-compile test asserting every generated module contains everything declared, for every transformer pairing |
| 3: Compile-time cross-resource introspection deadlock | Library Completion — finish Domain/Resource DSL split (`fix-application-generation`) | `mix compile` succeeds cleanly with resources + domain + application all present; no transformer calls `Info` on non-self modules |
| 4: Verifier gaps | Library Completion — capability checklist against `core`'s real patterns | Every DSL option has a verifier with a rejection test (see Pitfall 5 pattern) |
| 5: Contrived tests / test-env module-creation skip | Library Completion — documented testing story | No test asserts only `Code.ensure_loaded?/1`; skip flags are explicit and paired with a "real generation" test tier |
| 6: Upcasting done wrong | Library Completion (declarative upcasting) — gates `identity` domain migration specifically | Upcaster tested against a real captured historical payload of the pre-change shape |
| 7: Projector idempotency | Library Completion (projection expressiveness) — gates `data`/`workflow` migration | Redelivery test per generated projector: same event applied twice → identical resulting state |
| 8: Dispatch consistency / read-your-own-write | Library Completion (projection DSL) + per-domain migration checklist | Explicit `consistency` setting declared per projector; any read-after-write caller audited |
| 9: Aggregate design errors | Library Completion (aggregate invariants + non-attribute state) — gates `identity` migration | Per-domain: no command decision reads a projection; every non-attribute state field explicitly declared |
| 10: Test isolation / adapter drift | Library Completion (testing story + Postgres example app) — gates first domain migration validation | Shared app-restart case template exists; each migrated domain's suite also runs against Postgres adapter |
| 12: Incremental migration coexistence | Each per-domain migration phase | Cross-domain consumer audit as an explicit exit criterion, not just "this domain's tests pass" |
| 13: Behaviour-preserving migration verification | Each per-domain migration phase, preceding cutover | Golden-trace replay harness run for every migrated aggregate/projector against real historical events |

## Sources

- [Commanded — Events guide (upcasting, serialization guarantees)](https://commanded.hexdocs.pm/events.html)
- [Commanded.Event.Upcaster](https://commanded.hexdocs.pm/Commanded.Event.Upcaster.html)
- [Commanded.EventStore.TypeProvider](https://hexdocs.pm/commanded/Commanded.EventStore.TypeProvider.html)
- [`module_name_type_provider.ex` (Commanded source, GitHub)](https://github.com/commanded/commanded/blob/master/lib/commanded/serialization/module_name_type_provider.ex)
- [`json_serializer.ex` (Commanded source, GitHub)](https://github.com/commanded/commanded/blob/master/lib/commanded/serialization/json_serializer.ex)
- [`mapper.ex` (commanded-eventstore-adapter source, GitHub)](https://github.com/commanded/commanded-eventstore-adapter/blob/master/lib/commanded/event_store/adapters/event_store/mapper.ex)
- [Commanded.Projections.Ecto (commanded_ecto_projections docs)](http://hexdocs.pm/commanded_ecto_projections/Commanded.Projections.Ecto.html)
- [Commanded FAQ — dispatch consistency](https://github.com/commanded/commanded/wiki/FAQ)
- [Commanded — Testing guide](https://commanded.hexdocs.pm/testing.html)
- [Spark — Writing Extensions guide (transformer ordering, verifier-vs-transformer guidance)](https://spark.hexdocs.pm/writing-extensions.html)
- [Spark.Error.DslError](https://hexdocs.pm/spark/Spark.Error.DslError.html)
- [ash-project/ash — verifier-rejection test pattern, e.g. `test/policy/simple_test.exs`, `test/resource/identities_test.exs`](https://github.com/ash-project/ash)
- [Elixir Forum — "How to test a compile error?"](https://elixirforum.com/t/how-to-test-a-compile-error/15626)
- This repository's own source, read directly: `lib/commanded/transformers/generate_event_modules.ex`, `generate_projector_modules.ex`, `generate_aggregate_module.ex`, `generate_main_router_module.ex`, `generate_event_handler_modules.ex`, `base_transformer.ex`, `sections/events_section.ex`, and `test/commanded/verifiers/event_handler_tests.exs` — cited inline above wherever a claim is grounded in this codebase rather than upstream documentation.
- `.planning/PROJECT.md` and `.planning/codebase/CONCERNS.md` (required reading, this project) — origin of the already-identified debt items referenced throughout.

---
*Pitfalls research for: AshCommanded (Spark DSL / Commanded CQRS-ES library) + `core` migration*
*Researched: 2026-09-11*
