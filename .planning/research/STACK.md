# Stack Research

**Domain:** Elixir hex library — Spark DSL extension for Ash Framework, generating Commanded CQRS/ES code
**Researched:** 2026-09-11
**Confidence:** HIGH (all version numbers pulled live from hex.pm's package API and upstream `mix.exs`/`CHANGELOG.md` source on 2026-09-11; OTP/Elixir compatibility cross-checked against `elixir.hexdocs.pm` and `elixir-lang.org` release posts)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
| ------------ | --------- | --------- | ----------------- |
| Elixir | `~> 1.18` (floor), CI up to 1.20.4 | Language | "Current plus previous two minors" per project constraint. Current is 1.20 (June 2026), so the floor is 1.18 (Dec 2024). `~> 1.18` in a `mix.exs` version requirement means `>= 1.18.0 and < 2.0.0` — it already admits 1.19 and 1.20, so no upper bound is needed or wanted. |
| Erlang/OTP | 27–29 supported across the matrix | Runtime | Elixir 1.18 supports OTP 25–27; 1.19 supports OTP 26–28; 1.20 supports OTP 27–29. OTP 27 is the only version common to all three Elixir minors — pin CI's cross-version job to OTP 27, and add one forward-looking job at 1.20 + OTP 29. `core` currently runs OTP 27.3, so this keeps the library trivially installable alongside it. |
| Ash | `~> 3.0`, latest `3.33.3` | Framework being extended | ash_commanded is a Spark extension *for* Ash resources/domains — it must track Ash's DSL surface. `~> 3.0` still resolves correctly (no Ash 4.0 exists yet; `main` on GitHub is at 3.33.3, matching the latest hex release, so 3.x is still the active line). Ash's own CHANGELOG.md records exactly one `### Breaking Changes` section since the 3.0 release itself (dated with the 3.0 upgrade guide) — nothing breaking has landed between 3.5.8 and 3.33.3. |
| Spark | `~> 2.6`, latest `2.7.2` | DSL/transformer/verifier engine | Ash itself now requires `spark: ">= 2.6.0"` — declaring `~> 2.3` (current) risks a resolver conflict with recent Ash point releases in a consumer's deps tree. Spark's changelog shows its last `Breaking Changes` entry was 2.0.0 (Feb 2024, vendoring NimbleOptions); nothing breaking between 2.3.5 and 2.7.2. Bump the floor to `~> 2.6` to match Ash's own requirement and stay resolvable. |
| Commanded | `~> 1.4`, latest `1.4.11` | CQRS/ES runtime the generated code targets | 1.4.8 → 1.4.11 is patch-level only (no minor/major bump, no breaking-changes section in between). Elixir floor for Commanded itself is `~> 1.15` — compatible with our `~> 1.18` floor. Commanded's repo is active (pushed July 2026). Do not chase Commanded 2.x — it does not exist yet; the project's own "Out of Scope" note (targets Commanded 1.4.8 specifically) still holds against 1.4.11. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
| --------- | --------- | --------- | ------------- |
| `eventstore` | `~> 1.4`, latest `1.4.8` | Commanded's Postgres-backed event store adapter backend | Needed for the Postgres-backed example app (`.planning/PROJECT.md` "Active" item) proving the real persistence path `core` uses. Declare as `optional: true` or scope to `only: [:dev, :test]` (see Q3 below) — it is not needed to compile or use the DSL itself. |
| `commanded_eventstore_adapter` | `~> 1.4`, latest `1.4.2` | Wires `eventstore` into Commanded as its event store adapter | Same scope as `eventstore` — only the Postgres example app needs it. Last hex release Oct 2024; GitHub not archived, low churn is expected here since the adapter surface is small and stable. |
| `commanded_ecto_projections` | `~> 1.4`, latest `1.4.0` | Ecto-transaction-safe Commanded event handler behaviour for read-model projections | Only relevant if `GenerateProjectorModules` should optionally emit Ecto-transactional projectors (an option worth evaluating during the projector-expressiveness work in Active requirements) — otherwise out of scope for the core library. Last hex release Jan 2024; treat as low-churn infra, not stale — the API surface it wraps (Commanded event handlers) hasn't changed either. |
| `jason` | `~> 1.4`, latest stable `1.4.5` | JSON encoding, transitively required by Ash/Spark and used for `@derive Jason.Encoder` on generated events | `1.5.0-alpha.2` exists on hex but is a pre-release — do not depend on it. `>= 1.0.0` (Ash's own constraint) is looser than needed; `~> 1.4` is the honest floor given `core`'s usage. |
| `decimal` | (transitive via Ash, no direct dep needed) | Precise decimal arithmetic | Ash itself now declares `{:decimal, "~> 2.0 or ~> 3.0"}` — a deliberate either/or range spanning the 2.x→3.x major bump. Do not add a direct `decimal` dependency to `ash_commanded`'s `mix.exs` unless the library starts using `Decimal` directly; let it flow from Ash to avoid a second, potentially conflicting constraint. |

### Development Tools

| Tool | Purpose | Notes |
| ------ | --------- | ------- |
| `ex_doc` | Documentation generation | `~> 0.37` (current pin) → latest stable is `0.40.4`. No breaking changes surfaced in the 0.37→0.40 range that affect a standard `docs()` config (cheatsheets, mermaid/katex `before_closing_*_tag` hooks used in this project's `mix.exs` are unaffected). Bump to `~> 0.38` or looser to track current. |
| `sourceror` | AST parsing/codegen, dev/test only | `~> 1.8` (current pin) → latest `1.12.2`. Used for macro/codegen tooling, not runtime; bump freely to `~> 1.8` still resolves 1.12.x since `~> 1.8` means `>= 1.8.0, < 2.0.0`. No action required unless a newer minor's API is wanted — recommend leaving the constraint as `~> 1.8` (already permissive) rather than re-pinning tighter. |
| `igniter` | Code generation/project-patching framework, dev/test only | `~> 0.5` (current pin) → latest `0.8.4`. Igniter's CHANGELOG.md shows exactly one `### Breaking Changes` entry in its entire history, at `v0.4.8` (Nov 2024) — nothing breaking between 0.5 and 0.8.4. Existing `~> 0.5` constraint already resolves to 0.8.4; no mix.exs change strictly required, but consider `~> 0.6` as a floor bump once igniter-generated installer tasks are added (Igniter is the standard mechanism for a library to ship a `mix igniter.install ash_commanded`-style installer — worth adopting given the "repository tooling" active requirement). |
| `mock` | Test-only mocking (wraps `:meck`) | **Caution, not a version problem.** `0.3.9` is both the currently pinned version and the current hex-latest — the package has had no release since Dec 2024 (per hex.pm `updated_at`) and its GitHub repo's last push is also Dec 2024, with 26 open issues. It is not archived, but it is dormant. Elixir ecosystem convention for new test suites has moved toward `Mox` (behaviour-based, compile-time-checked contracts) over `mock`/`meck` (runtime module-patching, no compile-time contract). `mock` is currently used in 7 verifier test files in this repo, mocking concrete modules rather than behaviours — a pattern `Mox` does not support without introducing behaviours first. Recommendation: keep `mock` for now (no forcing function to migrate), but do not add new `mock`-based tests during the "contrived tests" overhaul already planned in Active requirements — write new tests against real modules or introduce explicit behaviours + `Mox` instead. |
| `credo` | Static analysis / style linting | Not currently declared. Latest `1.7.19` (June 2026). Recommend adding as `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` — standard for any hex library aiming at "production quality," and explicitly named in the CI recommendation below. |
| `dialyxir` | Dialyzer wrapper for static type-checking | Not currently declared. Latest `1.4.8` (Sept 2026, actively maintained). Recommend `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`. Given the generated-code nature of this library (transformers building modules from DSL data), Dialyzer is high-value for catching typespec drift in generated command/event/aggregate structs. |
| `sobelow` | Security static analysis for Phoenix/Elixir | Latest `0.15.0` (Aug 2026, actively maintained). Lower priority for a non-web library (no Plug/Phoenix endpoints), but cheap to add given `core`'s own tooling conventions likely already run it; optional. |
| `usage_rules` | LLM/agent rules synchronization tool | Latest `1.2.8` (Sept 2026, actively maintained by `ash-project`, i.e. the same org). See dedicated section below — this is a **dev-only** dependency plus a **published `usage-rules.md`** file, not a runtime dependency. |

## Installation

```elixir
# mix.exs — recommended deps() block
defp deps do
  [
    # Core — required to compile and use the DSL
    {:ash, "~> 3.0"},
    {:spark, "~> 2.6"},
    {:commanded, "~> 1.4"},

    # Optional — only needed by consumers who use the generated Commanded
    # application/router against a real event store, and by this repo's
    # example apps / integration tests. See Q3 rationale below for why
    # these are optional rather than hard runtime deps.
    {:eventstore, "~> 1.4", optional: true},
    {:commanded_eventstore_adapter, "~> 1.4", optional: true},

    # Dev/test tooling
    {:sourceror, "~> 1.8", only: [:dev, :test]},
    {:igniter, "~> 0.6", only: [:dev, :test]},
    {:mock, "~> 0.3.0", only: [:test]},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:usage_rules, "~> 1.2", only: [:dev]},

    # Documentation
    {:ex_doc, "~> 0.38", only: [:dev, :test], runtime: false}
  ]
end
```

```elixir
# mix.exs — elixir floor
elixir: "~> 1.18"
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
| ------------- | ------------- | ------------------------- |
| `commanded` as a hard runtime dep | `commanded` as fully consumer-supplied (not in `mix.exs` at all — the current, broken state) | Never for this library — see Q3. The library *generates code that calls Commanded macros/behaviours at compile time* (aggregates use `Commanded.Aggregate`-style callbacks, projectors use `Commanded.Projections.Ecto`/`Commanded.Event.Handler`). Compile-time codegen against an undeclared dependency is a correctness bug, not a style choice, and is already flagged in `.planning/codebase/CONCERNS.md`. |
| `eventstore` / `commanded_eventstore_adapter` as `optional: true` | Hard runtime deps | If the library ever ships a "batteries-included Postgres starter" as its *only* supported path (unlikely — Commanded supports multiple event store adapters, e.g. in-memory for tests). Keep optional so consumers using a different adapter (or the in-memory adapter for tests) aren't forced to compile Postgres client code. |
| `mock` (kept as-is) | `Mox` | If/when the "contrived tests" overhaul (Active requirement) introduces explicit behaviours for the pieces currently tested by mocking concrete modules (e.g., an `AshCommanded.SnapshotStore` behaviour, already partially present per PROJECT.md's snapshot adapter interface) — those new behaviour-backed tests should use `Mox`, not `mock`. |
| `~> 1.18` Elixir floor | `~> 1.19` or `~> 1.20` | If `core` moves off 1.18 as its own floor and the maintainers decide not to support Elixir versions `core` no longer runs — but the project's own constraint ("previous two minors" + "must remain installable alongside `core`") argues for keeping 1.18 as the floor now. |

## What NOT to Use

| Avoid | Why | Use Instead |
| ------- | ----- | ------------- |
| `spark ~> 2.3` (current pin) | Ash's own `mix.exs` now requires `spark: ">= 2.6.0"`. A consumer with a recent Ash resolved will hit a version conflict trying to satisfy both `ash_commanded`'s `~> 2.3` and Ash's `>= 2.6.0` if Hex's resolver ever needs the tightest common bound — and more importantly, `~> 2.3` communicates false information about what's actually been exercised in CI. | `{:spark, "~> 2.6"}` |
| `jason ~> 1.5` or the `1.5.0-alpha.*` releases | `1.5.0` has no stable release yet (only two alpha tags on hex as of 2026-09-11) | `{:jason, "~> 1.4"}` |
| Leaving `:commanded` and `:event_store` undeclared in `mix.exs` | Already flagged in this project's own `CONCERNS.md` — generated code references Commanded macros/behaviours at compile time with no declared dependency providing them. This is not "letting the consumer choose a version," it's an undeclared compile-time dependency that happens to work only because every current consumer's own deps tree already happens to include Commanded transitively or directly. | Declare `{:commanded, "~> 1.4"}` as a hard dep (see Q3) |
| `elixir: "~> 1.14"` (current pin) | Untested reach per the project's own Key Decisions ("`~> 1.14` was untested reach"). 1.14 is 4+ major Elixir releases and roughly 3.5 years behind current (1.14 → Sept 2022 era; current is 1.20, June 2026) — CI does not actually exercise anything below whatever floor is chosen, so the declared constraint is aspirational, not verified. | `elixir: "~> 1.18"`, CI-tested across 1.18/1.19/1.20 |

## Stack Patterns by Variant

**If publishing the Postgres-backed example app (Active requirement):**

- Add `eventstore`, `commanded_eventstore_adapter`, and optionally `commanded_ecto_projections` as dev/test-only or example-app-scoped deps
- Because the core library and its DSL must stay adapter-agnostic; only the *example* needs a concrete event store

**If publishing the in-memory example app (Active requirement, CI-friendly):**

- No extra deps beyond `commanded` itself — `Commanded.EventStore.Adapters.InMemory` ships inside the `commanded` package
- Because this is the fast, no-external-services path that should run in every CI job, not just an integration-tagged one

**If adding an Igniter-based installer task (`mix igniter.install ash_commanded`):**

- Bump `igniter` floor to `~> 0.6` and add an `installer` mix task under `lib/mix/tasks/`
- Because Igniter is the ash-project ecosystem's standard mechanism for "add this dependency and patch my project's config/resources for me," and this library's target audience (Ash Framework users) already expects it from sibling packages (`ash_postgres`, `ash_graphql`, etc.)

## Version Compatibility

| Package A | Compatible With | Notes |
| ----------- | ------------------ | ------- |
| `ash 3.33.3` | `spark >= 2.6.0` | Verified directly from Ash's own `mix.exs` on `main` (2026-09-11) — this is a hard floor Ash itself enforces, not a suggestion. |
| `ash 3.33.3` | `ecto ~> 3.14`, `decimal ~> 2.0 or ~> 3.0`, `jason >= 1.0.0`, `telemetry ~> 1.1`, `reactor ~> 1.0`, `splode ~> 0.3` | These are all transitive through Ash; `ash_commanded` should not declare its own conflicting constraints on any of them. |
| `commanded 1.4.11` | `elixir ~> 1.15` | Confirmed from Commanded's own `mix.exs`. Compatible with the recommended `~> 1.18` floor for `ash_commanded` (1.18 > 1.15). |
| `eventstore 1.4.8` | `elixir ~> 1.11` | Looser floor than Commanded's; not a constraint concern. |
| Elixir `1.18.x` | OTP 25, 26, 27 | Per `elixir.hexdocs.pm/compatibility-and-deprecations.html`: "the last three Erlang major versions by the time Elixir is released." |
| Elixir `1.19.x` | OTP 26, 27, 28 | Same source. Also: 1.19 officially requires OTP 28.1+ for *some* features (per the 1.19 release blog post), but the general compatibility table lists 26–28 as the supported range for running 1.19 at all. |
| Elixir `1.20.x` | OTP 27, 28, 29 | Same source; OTP 29.0.x is current as of Sept 2026. |
| `core` (this org's consuming app) | Elixir 1.18.4, OTP 27.3 | From `.planning/codebase/STACK.md`. This sits inside all three Elixir minors' OTP ranges — OTP 27 is the safe common denominator for the primary CI job. |

## CI Matrix (Q5)

Recommended GitHub Actions matrix (using `erlef/setup-beam`, the standard action for this — do not hand-roll Erlang/Elixir installation):

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - elixir: "1.18.5"
            otp: "25.3"
            lint: false   # floor check: oldest Elixir x oldest OTP it claims to support
          - elixir: "1.18.5"
            otp: "27.3"   # matches core's runtime exactly
            lint: false
          - elixir: "1.19.6"
            otp: "27.3"
            lint: false
          - elixir: "1.20.4"
            otp: "27.3"
            lint: true    # primary lint/dialyzer/format job
          - elixir: "1.20.4"
            otp: "29.0"   # forward-compatibility check
            lint: false
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-${{ matrix.elixir }}-${{ matrix.otp }}-
      - run: mix deps.get
      - run: mix format --check-formatted
        if: matrix.lint
      - run: mix credo --strict
        if: matrix.lint
      - run: mix compile --warnings-as-errors
      - run: mix test
      - run: mix dialyzer
        if: matrix.lint
      - run: mix docs
        if: matrix.lint
```

Rationale for this shape over the `ash-project`-org convention: the `ash-project` GitHub org (ash, spark, igniter, and their siblings) actually delegates CI to a shared reusable workflow (`ash-project/ash/.github/workflows/ash-ci.yml`) that assumes org-level secrets (`HEX_API_KEY`, Oban Pro licensing, etc.) and org-owned actions (`team-alembic/staple-actions`). `ash_commanded` lives under `accountex-org`, not `ash-project`, so reusing that workflow directly would create a dependency on infrastructure this project doesn't control. The matrix above reproduces the *substance* of that convention (format check → credo → compile with warnings-as-errors → test → dialyzer → docs, across an Elixir/OTP matrix) using only public, standard GitHub Actions (`erlef/setup-beam`, `actions/cache`) that any hex library maintainer can run unmodified.

## `usage_rules` Setup for a Library (Q4)

`ash_commanded` is the **producer** side of `usage_rules`, not the consumer side that `core` already exercises (`core` uses `usage_rules ~> 1.2` to *pull in* rules from its own deps). The setup differs:

1. **Write `usage-rules.md` at the package root** (next to `mix.exs`). This is a condensed, agent-facing reference for the DSL: what `commands`/`events`/`projections`/`event_handlers`/`application` sections exist, key options, transformer ordering constraints, and testing conventions (once the "documented testing story" Active requirement lands). The `usage_rules` maintainers' own advice: point an agent at your existing docs/cheatsheets and have it draft this file first, then hand-edit.
2. **For sub-topics that deserve their own file** (e.g., a dedicated snapshotting or upcasting guide), add a `usage-rules/` directory alongside it:

   ```text
   usage-rules.md
   usage-rules/
     projections.md
     upcasting.md
   ```

3. **Publish both with the hex package** by adding them to the `files:` list in `package()` in `mix.exs`:

   ```elixir
   defp package do
     [
       # ...
       files: ~w(lib mix.exs README.md LICENSE .formatter.exs usage-rules.md usage-rules)
     ]
   end
   ```

   Without this, the file exists in the git repo but is never shipped to consumers who install from hex.pm.
4. **No `:usage_rules` key belongs in `ash_commanded`'s own `mix.exs`** — that configuration key is read by `mix usage_rules.sync` in *consuming* applications, telling it which of their deps to pull rules from (e.g., `core`'s own `mix.exs` would add `:ash_commanded` to its `usage_rules:` list once this ships). `ash_commanded` only needs `usage_rules` itself as a `{:usage_rules, "~> 1.2", only: [:dev]}` dependency if the maintainers want to run `mix usage_rules.sync` locally to pull in *Ash's and Spark's* own `usage-rules.md` files while developing the extension — genuinely useful given how much of this library's surface is "how does Spark expect transformers/verifiers to behave."
5. **Precedent already exists**: `core` (the sibling consuming app) already depends on `usage_rules ~> 1.2` per `.planning/PROJECT.md`, so downstream tooling to consume `ash_commanded`'s new `usage-rules.md` is already wired up in the target consumer — publishing the file is pure upside with no new integration risk.

## Sources

- `https://hex.pm/api/packages/{ash,spark,commanded,eventstore,commanded_eventstore_adapter,commanded_ecto_projections,usage_rules,ex_doc,sourceror,igniter,mock,jason,decimal,ecto,reactor,telemetry,splode,credo,dialyxir,sobelow}` — HIGH confidence, hex.pm's own package API, queried live 2026-09-11. This is the authoritative registry; every version number above comes from this call.
- `https://raw.githubusercontent.com/ash-project/ash/main/mix.exs` — HIGH confidence, primary source, confirms Ash's own `spark`, `ecto`, `decimal`, `jason`, `telemetry`, `reactor`, `splode`, `elixir` constraints as of the current `main`/3.33.3.
- `https://raw.githubusercontent.com/ash-project/ash/main/CHANGELOG.md`, `.../spark/main/CHANGELOG.md`, `.../igniter/main/CHANGELOG.md` — HIGH confidence, primary source, grepped directly for `### Breaking Changes` sections to establish what changed since the previously-pinned versions.
- `https://raw.githubusercontent.com/commanded/commanded/main/mix.exs`, `https://raw.githubusercontent.com/commanded/eventstore/master/mix.exs` — HIGH confidence, primary source, confirms each package's own Elixir floor.
- `https://api.github.com/repos/commanded/commanded`, `https://api.github.com/repos/jjh42/mock` — HIGH confidence, GitHub API, confirms repo activity/staleness signals (`pushed_at`, `archived`, `open_issues_count`).
- `https://elixir.hexdocs.pm/compatibility-and-deprecations.html` (via WebFetch) — MEDIUM-HIGH confidence; official Elixir docs, summarized by an intermediate fetch/summarize step rather than read verbatim, but content matches the independently-confirmed release dates below.
- `https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released/`, `https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/` (via WebFetch) — MEDIUM-HIGH confidence; official release announcements, same caveat as above.
- `https://endoflife.date/elixir` (via WebFetch) — MEDIUM confidence; third-party tracker, used only to cross-check release dates/support windows against the official sources, not as a sole source.
- `https://api.github.com/repos/elixir-lang/elixir/releases` — HIGH confidence, GitHub API, gives exact current patch versions (1.18.5, 1.19.6, 1.20.4, all published 2026-08-28).
- `https://usage-rules.hexdocs.pm/readme.html` (via WebFetch) — MEDIUM-HIGH confidence; official package docs for the library-author workflow described in the `usage_rules` section above.
- `https://github.com/ash-project/spark/blob/main/.github/workflows/elixir.yml`, `https://raw.githubusercontent.com/ash-project/ash/main/.github/workflows/ash-ci.yml` — HIGH confidence, primary source, used to explain (and explicitly diverge from) the `ash-project`-org CI convention in the CI Matrix section.
- `.planning/PROJECT.md`, `.planning/codebase/STACK.md`, `mix.exs` (this repo) — HIGH confidence, required reading, establishes the current pinned versions this research bumps from.

---
*Stack research for: Elixir hex library — Ash/Spark DSL extension for Commanded CQRS/ES*
*Researched: 2026-09-11*
