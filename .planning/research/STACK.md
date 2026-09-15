# Stack Research: Enforcement Tooling for the Macro-Heavy Rewrite

**Domain:** Static analysis / code-quality tooling for a Spark DSL that generates Elixir modules
**Researched:** 2026-09-15
**Confidence:** MEDIUM-HIGH overall — HIGH for what exists off-the-shelf, LOW-flagged explicitly
where no tool can do the job (see Rule 5 and part of Rule 3)

## tl;dr Verdict Table

| # | Rule | Off-the-shelf? | Verdict | Effort if hand-written |
| --- | ------ | ----------------- | --------- | ------------------------- |
| 1/3 | Generated clause <10 lines, `quote` block <40 lines, **measured on emitted output** | No | **BUILD** — small script/test over rendered golden files | 0.5–1 day (reuses the planned renderer) |
| 2 | Compile-time-computable values folded, never reassembled at runtime (`:erlang.++` case) | No | **BUILD** — Credo check or plain scan over rendered output | 0.5–1 day |
| 3 | Idiomatic macros; anti-pattern = build strings/maps → reparse into AST | Partially | **BUILD** — (a) grep-style Credo check for `Code.string_to_quoted`/`eval_string` (cheap, precise) + (b) unquote-ratio metric (heuristic, weaker) | (a) 2–4 hrs; (b) 1–2 days, treat as advisory not a gate |
| 4 | DRY — repeated AST shapes across generator modules | **Yes** | **ADOPT** — `ex_dna` (Credo plugin, structural clone detection) | ~1 hr integration |
| 5 | No double-handling — re-deriving a value the caller already holds | No | **NO MECHANICAL CHECK EXISTS.** State this plainly to the roadmap — it is a design-review rule, not a lint rule. A narrow proxy (flag `Macro.prewalk/postwalk` calls inside transformers as a review trigger) is possible but not a real check | N/A — do not attempt to fully automate |

The single biggest structural finding: **there is no tool anywhere in the Elixir ecosystem that
measures the size or shape of macro-*emitted* code** — every static analysis tool (Credo, ex_dna,
Sourceror-based checks) operates on source text/AST as it exists in `.ex` files on disk. The
project's own planned foundation piece — `mix ash_commanded.dump` rendering generated code to text,
committed as golden files — is what makes emitted output visible to any of these tools at all. Once
rendered to text, ordinary tools (Credo, `ex_dna`, even `wc -l`) become usable against output, not
just against generator source. This is the load-bearing insight for the Foundation phase: **build
the renderer first, and several of these "no tool exists" problems become 2–4 hour scripts against
rendered text** rather than open research questions.

---

## Recommended Additions

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
| ------------ | --------- | --------- | ----------------- |
| `ex_dna` | 1.5.1 (hex, MIT, `elixir-vibe/ex_dna`, 116★, actively released) | Structural (Type-I/II/III) code-duplication detection on Elixir AST | Rule 8/4 (DRY) is exactly its purpose. Ships as a Credo plugin that **replaces** Credo's own weaker `Credo.Check.Design.DuplicatedCode` (Type-I-only, mass/nodes-threshold heuristic). Fast enough for real codebases (author benchmarks: Ash itself, 554 files, ~6s). Verify its declared Elixir/OTP floor against 1.18/OTP 27 at adoption time — not independently confirmed in this research, flag as MEDIUM confidence on that one point only |
| `credo` | 1.7.18 (current, released 2026-06-05) | Host for all hand-written custom checks below | Already a project dependency; nothing to change except bumping the pin and adding `requires:` entries for new in-repo checks |
| `sourceror` | 1.12.2 (current; project currently pins `~> 1.8`, already a dep) | AST-shape traversal for the custom checks below (quote-block extraction, unquote-node counting, comment-preserving parse) | Already a dependency for other reasons (codemods/`igniter`). Reuse it rather than hand-rolling AST walkers — it has a zipper API purpose-built for "find this shape, count that shape" queries, which is most of what Rules 2 and 3 need. **Bump the pin**: `~> 1.8` is stale against 1.12.2, and nothing in the constraints requires staying old |

### What NOT to Add

| Avoid | Why | Use Instead |
| ------- | ----- | -------------- |
| **`ash_credo`** as a runtime dependency | Its own README states the project is "experimental and might break frequently"; only 2 of its checks are even enabled by default. It targets **consumers of Ash resources** (people writing `commanded do ... end` blocks), not **authors of the transformers that generate code** — the wrong audience for this milestone. It is genuinely useful as *design precedent* (see below), not as a dependency | Write AshCommanded's own checks in-repo, informed by its dual-analysis pattern |
| **`ex_slop`** (`elixir-vibe/ex_slop`, "AI slop" Credo checks) | Confirmed via its own docs: none of its 40 checks touch macros, `quote` blocks, generated-code size, or AST duplication — it targets ordinary hand-written-code smells (blanket rescues, N+1, narrator comments). Not wrong to run generally, but irrelevant to this milestone's rules | N/A — orthogonal, could be added later for general code hygiene if wanted, not part of this enforcement set |
| **`mneme`** or **`assert_value`** as the golden-render mechanism | Both are real, actively maintained snapshot-testing tools (mneme: v0.10.2, 555 commits, `CI=true` correctly fails rather than prompts; assert_value: mature, referenced by mneme's own docs as more feature-rich). But both work by **embedding the expected value as a literal inside the test source file** via interactive accept/reject. A rendered aggregate module is 300+ lines (see LEARNINGS.md, §1 — the 333-line fixture render). Embedding that as a heredoc inside a `_test.exs` file fights the actual goal stated in PROJECT.md: *"golden renders of generated output, diffed in CI"* — i.e. reviewable in a normal `git diff` on a PR, the way any other generated-and-committed artifact is reviewed | Hand-roll a plain file-based golden harness (below) — this is the standard, library-free pattern used across the Elixir/BEAM ecosystem for exactly this shape of problem (large rendered text compared to a committed reference file) |
| **`Credo.Check.Design.DuplicatedCode`** (built-in) left enabled alongside `ex_dna` | It's Type-I only (near-identical AST, not semantically-equivalent-but-restructured clones) and known to have false-negative gaps with macro-heavy code (see `#518` — `excluded_macros` doesn't fully exclude test-generated duplicates). Running both is redundant and doubles noise | Disable the built-in check in `.credo.exs`, enable `ex_dna`'s replacement per its own integration docs |
| **`approval`** / **`ApprovalTests.Elixir`** (tmbb, approvals org) | Both surfaced in research but show weak signals of current maintenance (no clear recent-release evidence found; `ApprovalTests.Elixir` is a thin port of a multi-language framework not idiomatic to BEAM tooling) — do not adopt without independently re-verifying activity immediately before use | Same hand-rolled harness as above |

---

## Rule-by-Rule Detail

### Rules 1 & 3 (PROJECT.md numbering) — thin wiring, measured on OUTPUT not generator source

**No tool measures emitted macro output.** This was checked directly and confirmed absent: Credo,
`ex_dna`, Dialyzer, and every "code size" tool found operate on `.ex`/`.exs` files as authored, and
none of them expand macros before analysis (Dialyzer analyzes compiled BEAM abstract code, but its
purpose is type success typing, not size/style — it has no "function too long" or "block too big"
check of any kind, and was not designed to).

**Build it, cheaply, once the renderer exists.** The milestone already plans `mix ash_commanded.dump`
(pre-`Module.create/3` AST) and golden files. Once generated code exists as committed text:

1. Parse each golden file with `Code.string_to_quoted!/1` (stdlib, no new dependency).
2. Walk top-level `def`/`defp` clauses; for each, use the AST's line metadata (`Macro.postwalk`
   collecting `meta[:line]` across all descendant nodes of that clause) to get `max_line - min_line`
   as the clause's emitted line count.
3. Assert (in a plain ExUnit test or a small `mix ash_commanded.check_output_size` task) that no
   clause exceeds ~10 lines and no single top-level construct exceeds 40.
4. Run this test against every file in the golden directory — it is now a regression gate, not a
   one-time audit.

Effort: 0.5–1 day, stdlib only (`Code`, `Macro`). This is a genuinely small addition on top of
foundation work the project is already committed to, which is why it belongs in the Foundation phase
rather than being deferred.

**Explicitly answers the question "does splitting a fat generator across modules dodge this?"** — no,
because the check runs against the *rendered output*, not the transformer's own source file line
count. A generator split across five files that still emits one 225-line `execute/2` clause fails the
check exactly as it does today undivided.

### Rule 2 — fold compile-time-computable values, never reassemble at runtime

The concrete instance in LEARNINGS.md §1 (six nested `:erlang.++` calls on mostly-empty lists) is
detectable mechanically **in the rendered output**, not in generator source (the generator source
"does not look like this" — the render does, per the same section). Build a Credo check (or even a
plain script, given it only needs to run against the golden directory) that walks each rendered
module's AST and flags:

- `{{:., _, [:erlang, :++]}, _, _}` calls (the compiled form of `++`)
- `{:++, _, [_, _]}` where either operand is itself a literal list/keyword-list (a strong signal that
  something fully knowable at expansion time was left as a runtime operation)

Because the *emitted* code of a correctly-generated "thin wiring" module should almost never contain
`Kernel.++`/`:erlang.++` at all (the whole point of `unquote` is that list-building happens once, at
expansion time), a simple "flag any occurrence" rule is precise enough here — false positives should
be rare and each is worth a look. Effort: 0.5–1 day, using `Credo.Code.prewalk/2` (a thin wrapper
around `Macro.prewalk/3`) or Sourceror for the AST walk.

### Rule 3 (idiomatic macros) — two separable checks, different confidence

**(a) The concrete anti-pattern — HIGH confidence, cheap.** "Building lists of tuples and maps,
joining them into strings, and reparsing into AST" has a precise mechanical signature: calls to
`Code.string_to_quoted/1,2`, `Code.string_to_quoted!/1,2`, or `Code.eval_string/1,2,3` appearing
inside `lib/**/transformers/*.ex` or `lib/**/sections/*.ex`. A Credo check that greps for these three
call shapes via `Credo.Code.prewalk/2` is precise, has essentially no false positives in a codebase
whose transformers should never need runtime code-from-string, and is a half-day task including
tests.

**(b) "Static-to-substitution ratio" as a literal metric — MEDIUM confidence, heuristic, do not gate
on it alone.** It is measurable: use Sourceror to find every `quote do ... end` (or `quote bind_quoted:
... do ... end`) block in generator source, count total AST nodes in its body versus nodes matching
`{:unquote, _, _}` / `{:unquote_splicing, _, _}`, and compute a ratio. This can flag outliers (a quote
block with almost no unquote holes relative to its size, versus one built entirely from a handful of
substitutions). Recommend building it (1–2 days) but treating its output as **advisory input to the
per-component render-and-approve review**, not a blocking gate — a low ratio is *consistent with* the
anti-pattern but is not equivalent to it (a legitimately large, mostly-static `quote` block with one
substitution is not automatically wrong; the aggregate generator's 225-line block was wrong because
of what was *inside* it — runtime list-building — which check (a) plus the size gate (Rules 1/3
above) already catch more precisely). Do not let (b) become the primary enforcement mechanism; it is
the least mechanically precise of everything in this document.

### Rule 4 — DRY across generator modules: adopt `ex_dna`

This is the one rule with a genuine off-the-shelf answer. `ex_dna` operates directly on Elixir AST
(not text/token matching, unlike `jscpd` which it explicitly positions itself against), doing
Type-I/II/III structural clone detection, and ships as a drop-in Credo plugin replacing the built-in
`DuplicatedCode` check. Integration is `.credo.exs` configuration, not code — roughly an hour
including tuning `mass_threshold`/`nodes_threshold`-equivalent parameters for this codebase's
generator style. It also has JSON/SARIF output for CI annotation if that is later wanted, and an LSP
server, neither required for this milestone but free.

Confidence: MEDIUM-HIGH. The library is small (116 stars) relative to Credo itself, so verify at
adoption time that `mix.lock` resolution against the pinned `ash`/`spark`/`commanded` versions is
clean — no conflict was found in this research, but it wasn't independently resolved in this repo's
`mix.exs` at research time.

### Rule 5 — no double-handling: **no tool, state this plainly**

This rule asks whether a value the caller already holds is being re-derived by re-walking AST. That
is a *data-flow ownership* question — "does the caller already have this?" — which requires knowing
what's available in scope at a call site and reasoning about whether a second computation is
redundant with it. No static analysis tool (Credo, Dialyzer, `ex_dna`, Sourceror-based custom checks)
reasons about redundant-but-not-identical computation paths; this is squarely outside AST-shape
matching. Dialyzer's success typing does not detect this either — two different mechanisms computing
the same value from different paths are not a type error.

**The honest answer for the roadmap:** this rule is enforced by the render-and-approve human review
step (Rule 7, "golden renders diffed in CI") and by code review, not by a mechanical check. A weak,
narrow proxy exists — flag any call to `Macro.prewalk/2,3`, `Macro.postwalk/2,3,4`, or
`Macro.traverse/4` inside a transformer module as a review trigger (not a failing check), on the
theory that re-walking AST is *sometimes* evidence of re-deriving something `Transformer.get_persisted/2`
already has. This is cheap to add (a few hours, as a Credo check with `category: :consistency` and
non-blocking severity) but it is a nudge, not enforcement — say so explicitly rather than presenting
it as solving the rule.

---

## Golden-File / Snapshot Testing

**Researched candidates:** `mneme` (0.10.2, actively maintained, `zachallaun/mneme`, 555 commits,
correct `CI=true` → reject-and-fail behavior, requires Elixir ≥1.14), `assert_value`
(`assert-value/assert_value_elixir`, mature, described by mneme's own docs as "more feature-rich and
more polished" than typical snapshot libraries), `snapshy` (`DCzajkowski/snapshy`, smaller/simpler,
explicitly cites `assert_value_elixir` as the more capable option), `approval`/`ApprovalTests.Elixir`
(weaker maintenance signal, not independently re-verified as current).

**Verdict: hand-roll a plain file-based golden harness; do not adopt any of the above as the primary
mechanism.** Reasoning:

1. **Size.** Renders are hundreds of lines (the LEARNINGS.md §1 aggregate-fixture render is 333
   lines). All of the libraries above work by embedding the expected value as a literal *inside the
   test file* (a heredoc `auto_assert(render <- """ ... """)` for mneme, similarly for
   `assert_value`). A several-hundred-line heredoc inside a `_test.exs` file is unreviewable in a PR
   diff the way a standalone `test/golden/aggregate_one_command_one_event.golden.exs` file is.
2. **What "diffed in CI" means here.** PROJECT.md's own phrasing — "golden renders of generated
   output, diffed in CI" — describes source-controlled artifacts reviewed the way any other generated
   file is reviewed (a PR that changes a generator shows the golden-file diff directly), not an
   interactive test-assertion workflow. That is a plain golden-file pattern, not a snapshot-assertion
   library's use case.
3. **Effort to hand-roll is trivial and this is exactly the shape of the problem already being
   solved by `scripts/render_generated.exs` and `test/support/parity/`.** A golden harness is:
   - a directory of committed reference files (`test/golden/*.golden.ex`),
   - a helper that calls the renderer, and
   - a comparison that fails with a readable diff when the fresh render doesn't match the committed
     file, with a `GOLDEN_UPDATE=true mix test` escape hatch to regenerate references after an
     intentional change (the same idiom `insta` uses in Rust and many BEAM projects use ad hoc).
   Total: roughly 2–4 hours, ExUnit + `File.read!/1` + `File.write!/1`, no new dependency.

**mneme remains worth keeping in mind for a different, narrower use** — auto-updating assertions on
smaller structured values elsewhere in the test suite (e.g., asserting the shape of a parsed DSL
entity struct) — but that is a separate decision from the golden-render mechanism this milestone
needs, and is out of scope for the Foundation phase.

---

## Writing Custom Credo Checks

**API (current, Credo 1.7.18, verified against `credo.hexdocs.pm/adding_checks.html`):**

```elixir
defmodule AshCommanded.CredoChecks.NoRuntimeStringToAst do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [],
    explanations: [check: "Transformers must not build AST from interpolated strings."]

  @doc false
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({{:., _, [{:__aliases__, _, [:Code]}, fun]}, meta, _args} = ast, issues, issue_meta)
       when fun in [:string_to_quoted, :string_to_quoted!, :eval_string] do
    {ast, [issue_for(issue_meta, meta[:line], fun) | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(issue_meta, message: "...", trigger: trigger, line_no: line_no)
  end
end
```

- Traversal: `Credo.Code.prewalk/2` is a thin wrapper around `Macro.prewalk/3` that operates on
  `SourceFile` structs; pattern-match the specific 3-tuple AST shapes for `quote`
  (`{:quote, _, _}`), `unquote` (`{:unquote, _, _}`), and the specific function-call shapes above.
- `run/2` returns a list of `%Credo.Issue{}` structs (built via `format_issue/2`), full stop — no
  other callback shape.
- **Testing:** `Credo.Test.Case` provides `to_source_file/1` (heredoc → `SourceFile`),
  `run_check/2`, and `assert_issue/2`, `assert_issues/2`, `refute_issues/1` — a normal ExUnit test
  module, no special harness needed.
- **Shipping location: keep these in-repo, not a separate Hex package.** `.credo.exs` supports a
  `requires: ["./lib/ash_commanded/credo_checks/**/*.ex"]` glob for local, project-owned checks —
  this is exactly the mechanism to use, since these checks police AshCommanded's *own* generator
  code, not code written by consumers of the DSL. Exclude the checks directory from `mix.exs`'s
  `files:` list so it doesn't ship inside the published Hex package (consumers get the library, not
  its internal lint rules). If the project later wants an `ash_credo`-style companion that checks
  *consumers'* `commanded do ... end` blocks for misuse, that is a legitimately separate package
  (precedent: `ash_credo`, `chazsconi/credo_pure_check` — small, single-purpose Credo-check packages
  are a normal, low-ceremony thing to publish in this ecosystem) — but that is future scope, not this
  milestone's Foundation phase.

---

## Compile-Time Tracing

Elixir supports two distinct mechanisms, both real but **neither adds much beyond what the project
has already prototyped**:

- **Compiler tracers** (`:tracers` compiler option / `mix compile.elixir --tracer`): a module
  implementing `trace/2`, invoked synchronously during compilation for every construct the compiler
  handles. Must dispatch work off-process to avoid slowing compilation. Useful for building a
  project-wide manifest of "which modules did this DSL emit across a full compile" — a generalization
  of what `scripts/compile_parity.sh` already does with an explicit expected-module list.
- **`@after_compile`**: a per-module callback invoked right after that module compiles, given the
  module and its `Macro.Env`. Could be injected by a generator into every module it creates, to
  self-report something at compile time.
- **Mix listeners** (`config :my_app, :listeners, [...]` in a long-running Mix task): receive
  `{:modules_compiled, info}` with added/changed/removed module diffs — relevant to *watch mode*
  tooling, not a one-shot CI check.

**Verdict: do not build new tracer infrastructure for this milestone.** The project's own prototype —
`scripts/render_generated.exs`, using `:beam_lib.chunks(path, [:debug_info])` to recover
post-compile AST and render it back to source (LEARNINGS.md §6) — already solves the "observe what a
DSL emitted" problem, and does so at the more useful pre-`Module.create/3` stage once
`mix ash_commanded.dump` lands (per PROJECT.md's own note that debug_info is post-macro-expansion,
so `use X` already shows as the functions it injected — the wrong view for the renderer's stated
purpose). Tracers/`@after_compile` would be additive complexity solving a problem the render pipeline
already owns. If a future need arises to verify *which* modules exist across a whole consuming
application (not just render one DSL definition's output), a compiler tracer is the right tool then —
flag it as a possible Phase 2+ technique for the router/event-handler component (which already needs
cross-module `Ash.Domain.Info.resources/1` walking), not a Foundation-phase item.

---

## Precedent in Spark/Ash's Own Ecosystem

- **`ash_credo`** (`cheerfulstoic/ash_credo`, also forked as `leonqadirie/ash_credo`) is the closest
  analog to what this milestone wants, but for the *other* audience: it lints resources written
  *using* Ash's DSLs, not the transformers that implement those DSLs. Its useful contribution to this
  research is architectural precedent: **it runs a dual analysis** — "some checks analyse unexpanded
  source AST; others introspect the compiled modules to see the fully-resolved DSL state, including
  anything Spark transformers and extensions contribute." That is precisely the split this milestone
  needs (Rules 1–3 need the *compiled/rendered* view; Rule 4 needs the *source* view of generator
  modules) — cite it as the pattern to follow, not as a dependency. Its own README calls the project
  experimental; do not depend on it.
- **Spark itself** ships no self-policing of the DSLs it powers — it is a DSL-authoring framework,
  not a linter, and neither Spark's nor Ash's own repos were found to contain anything that measures
  generated-code size or unquote ratios. The `Transformer.get_persisted/2` / prefer-a-verifier /
  introspection-belongs-in-`ModuleName.Info` guidance already captured in LEARNINGS.md §4 is Spark's
  own upstream guidance, already known to the project — no new tooling follows from it, it is a
  coding convention, enforceable only by the same custom Credo checks described above (a check could
  flag module-name string manipulation, e.g. `Module.concat` built from `to_string` splitting,
  instead of `Transformer.get_persisted(dsl_state, :module)` — cheap, precise, worth adding to the
  same custom-check set; roughly half a day, same `Credo.Code.prewalk/2` technique).

---

## Installation

```bash
# Dev/test-only additions
mix deps.get  # after adding to mix.exs:
# {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false}

# Bump existing pin (already a dependency)
# {:sourceror, "~> 1.12", only: [:dev, :test], runtime: false}   # was "~> 1.8"

# Credo itself — confirm current pin matches 1.7.18 or bump
# {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
```

No new *runtime* dependencies are implied by anything in this document — every recommendation here is
`:dev`/`:test`-only tooling, consistent with the project's existing `mix check` posture.

## Version Compatibility

| Package | Version (verified 2026-09-15) | Notes |
| --------- | ------------------------------- | ------- |
| `credo` | 1.7.18 (released 2026-06-05) | Current; `Credo.Test.Case` and `Credo.Code.prewalk/2` APIs used above are stable in this line |
| `sourceror` | 1.12.2 | Supports back to Elixir 1.10/OTP 21; no conflict with the project's Elixir 1.18/OTP 27 floor |
| `ex_dna` | 1.5.1 | MIT, `elixir-vibe/ex_dna`. Elixir/OTP floor not independently confirmed in this research — verify at `mix deps.get` time; flagged MEDIUM confidence on this one point only |
| `mneme` | 0.10.2 | Requires Elixir ≥ 1.14. Not recommended as the golden-render mechanism (see above); note only if adopted later for a narrower purpose |

## Sources

- [Credo — Adding Custom Checks (current docs)](https://credo.hexdocs.pm/adding_checks.html) — HIGH confidence, official docs, verified API shape
- [Credo.Test.Case testing API](https://hexdocs.pm/credo/Credo.Test.Case.html) — HIGH confidence, official docs
- [Credo.Check.Design.DuplicatedCode](https://hexdocs.pm/credo/Credo.Check.Design.DuplicatedCode.html) — HIGH confidence, official docs, confirms Type-I-only limitation
- [ex_dna (elixir-vibe/ex_dna)](https://github.com/elixir-vibe/ex_dna) — MEDIUM-HIGH confidence, GitHub repo + hexdocs, MIT, actively released, 116★
- [ex_slop (elixir-vibe/ex_slop)](https://github.com/elixir-vibe/ex_slop) — HIGH confidence for its stated scope (confirmed it does not touch macro/output-size checks); cited only as a "do not adopt for this purpose" reference
- [ash_credo (cheerfulstoic/ash_credo)](https://github.com/cheerfulstoic/ash_credo) — MEDIUM confidence; project self-describes as experimental, cited as design precedent only
- [mneme (zachallaun/mneme)](https://github.com/zachallaun/mneme) — HIGH confidence, actively maintained (555 commits), `CI=true` behavior confirmed via docs
- [Sourceror](https://hexdocs.pm/sourceror/readme.html) — HIGH confidence, official docs, v1.12.2 confirmed current
- [Elixir compiler tracers](https://hexdocs.pm/elixir/1.13/Code.html) / [Mix.Task.Compiler](https://hexdocs.pm/mix/Mix.Task.Compiler.html) — HIGH confidence, official docs
- LOW-confidence / not independently re-verified at time of writing: `approval`/`ApprovalTests.Elixir` maintenance status, `assert_value_elixir` current release date — do not adopt without a fresh maintenance check at implementation time

---
*Stack research for: enforcement tooling, AshCommanded v0.3 Library Rewrite, Foundation phase*
*Researched: 2026-09-15*
