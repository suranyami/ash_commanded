# .dialyzer_ignore.exs
#
# A dated snapshot of pre-existing Dialyzer debt, seeded once at the end of Phase 1
# (2026-09-14, Plan 01-07) via `mix dialyzer --format ignore_file_strict`, committed verbatim
# with no hand-written or hand-edited entries. Anything NEW that Dialyzer reports beyond this
# list blocks `mix dialyzer` — that is the point of seeding it (D-22). Later phases shrink
# this list; nobody should add to it without a stated reason.
#
# 2026-10-20 (plan 01-07, FOUND-18): the three `generate_aggregate_module.ex` entries were
# re-anchored to `test/support/parity/parity_widget.ex`, keeping their exact messages. FOUND-18
# attributes generated modules to the DSL declaration that produced them, so Dialyzer now
# reports these same three pre-existing findings against the parity fixture's source instead of
# the aggregate transformer's. Findings, messages and count are unchanged; only the attributed
# file moved, and re-anchoring is what keeps the ratchet anchored to reality rather than
# silently letting the findings escape it.
#
# 2026-10-21 (plan 01-11): the generated aggregate no longer emits runtime branches on
# compile-time literals, so "The guard clause can never succeed." no longer has a finding to
# skip. Removed rather than kept: an unused filter means the entry and reality have diverged,
# which is the direction that lets a new finding escape unnoticed.
[
  {"test/support/parity/parity_widget.ex", "The pattern can never match the type true."},
  {"test/support/parity/parity_widget.ex",
   "The pattern variable _ can never match the type, because it is covered by previous clauses."},
  {"lib/ash_commanded/domain/transformers/generate_commanded_application.ex",
   "Unknown type: Spark.Dsl.Transformer.t/0."}
]
