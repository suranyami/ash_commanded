# Golden renders

This directory holds one committed golden per module `AshCommanded`'s transformers generate for
a fixture, foldered per fixture: `test/golden/<fixture>/<GeneratedModule>.golden` (D-10). Each
golden is the pre-`Module.create/3` AST, rendered exactly as `mix ash_commanded.dump` renders it
by default — the same view a developer sees when reading generated output before it is approved
(the fourth step of this milestone's per-component method).

## Regenerating goldens (FOUND-05)

There is exactly one documented command:

```sh
mix ash_commanded.dump <Fixture> --write
```

`--write` re-renders every module the given fixture (a resource or domain module carrying a
`commanded do ... end` block) generates and writes each one's golden. Run `git diff` afterward —
it will show exactly the change you made. Running `--write` when nothing changed leaves
`test/golden/` byte-for-byte identical (`git diff --exit-code -- test/golden/` stays clean).

Narrow a single module with `--only <GeneratedModule>` if you only touched one generator.

## The header

Every golden's first line is a budget header:

```text
# gsd-budget: clause_max=6 module_lines=48
```

`clause_max` is the widest `def`/`defp` clause span in the file (in lines); `module_lines` is
the whole rendered body's line count. `test/ash_commanded/golden_budget_test.exs` re-measures the
committed body against these numbers on every `mix test` run — a golden that no longer matches
its own declared header fails independently of whether the *text* still matches (D-03).

Sizes only ever ratchet down or hold. `--write` accepts a render that shrank or held every number
against what is already committed, rewriting the header to the new, smaller numbers. If any
number would **grow**, `--write` refuses — it writes nothing, exits non-zero, and prints the
budget key that would grow, its old and new value, and the golden's own path and header line
number (D-11).

## What the refusal means and how to answer it

A refusal is not a bug in `--write` — it means the render actually got bigger, and that needs a
human decision, not a rubber stamp. Two answers:

1. **The growth is a regression.** Fix the generator so the render shrinks back down, then
   `--write` again.
2. **The growth is intentional** (a deliberate feature addition, for instance). Edit the
   `# gsd-budget:` header's number yourself, on the same line the refusal named, and add a
   one-line reason beside it. Because the golden is a committed file, that edit shows up in the
   pull request diff right next to the render that caused it — no separate approval mechanism
   exists (D-04).

## The staged marker

A golden whose measured `clause_max` exceeds FOUND-06's absolute ceiling of 10 lines carries a
second header line:

```text
# gsd-staged-until-phase: N
```

`N` is the roadmap phase that rewrites that generator (see `.planning/ROADMAP.md`). This exempts
the golden from the absolute ceiling only — the ratchet above still applies in full, so a staged
component cannot grow either. `AshCommanded.TestSupport.Parity.WidgetAggregate`'s golden is staged
until Phase 4 (Aggregates): the current aggregate generator inlines middleware, transactions and
parameter mapping directly into the emitted module (see `.planning/LEARNINGS.md` §1), and Phase 4
is what replaces that with a thin generated clause over a hand-written runtime module.

## What has no golden yet, and why

Domain-level application and router modules have no goldens in this phase. Those transformers do
not fire for any domain today — a defect recorded in `PROJECT.md`'s `Falsified` section, not an
oversight here. Phase 3 (Application and Routers) fixes the defect and adds their goldens then.

## Canonical Elixir version (D-12)

Goldens are generated on Elixir `~> 1.18` — the minor series declared in `test/test_helper.exs`.
`test/ash_commanded/golden_render_test.exs`'s text-diff comparison only runs on that version;
every other CI matrix leg still runs the full suite and the size gates above, which count sizes
rather than compare text and so hold on every Elixir minor.

## Runtime-reassembly lint (FOUND-08)

`test/ash_commanded/golden_budget_test.exs` also runs `AshCommanded.Dump.Lint` against every
committed golden's body, failing (naming the golden's path and the offending line) when a render
reassembles a compile-time-known value at runtime — the `:erlang.++`-shaped defect recorded in
`.planning/LEARNINGS.md` §1. This is a class of defect that is invisible in generator source and
visible only in rendered output, which is exactly why the renderer had to exist before it could be
enforced.
