# .dialyzer_ignore.exs
#
# A dated snapshot of pre-existing Dialyzer debt, seeded once at the end of Phase 1
# (2026-09-14, Plan 01-07) via `mix dialyzer --format ignore_file_strict`, committed verbatim
# with no hand-written or hand-edited entries. Anything NEW that Dialyzer reports beyond this
# list blocks `mix dialyzer` — that is the point of seeding it (D-22). Later phases shrink
# this list; nobody should add to it without a stated reason.
[
  {"lib/commanded/transformers/generate_aggregate_module.ex",
   "The pattern can never match the type true."},
  {"lib/commanded/transformers/generate_aggregate_module.ex",
   "The guard clause can never succeed."},
  {"lib/commanded/transformers/generate_aggregate_module.ex",
   "The pattern variable _ can never match the type, because it is covered by previous clauses."},
  {"lib/commanded/transformers/generate_commanded_application.ex",
   "Unknown type: Spark.Dsl.Transformer.t/0."}
]
