---
schema_version: 1
open_count: 10
waived_count: 0
fixed_count: 1
total_count: 11
last_updated: 2026-10-20T20:27:14.484Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | lib/commanded/snapshot_adapter.ex |  | Plan required unconditional @behaviour Commanded.Aggregates.Aggregate.Snapshotter; that module does not exist anywhere in commanded 1.4.11 (verified against deps/commanded), so the behaviour was removed entirely instead of made unconditional | open |  | 2026-09-14T00:27:47.341Z |  |
| 2 | 01 | todo | lib/commanded/transformers/generate_event_handler_modules.ex | 95 | Generated execute_action/2 calls Ash.run_action/3, which does not exist (Ash.run_action/2 takes an ActionInput). Never exercised at runtime by any test; correct fix requires branching on the target action's real type | open |  | 2026-09-14T00:27:47.407Z |  |
| 3 | 01 | deviation | .credo.exs |  | Design.AliasUsage moved to disabled: rather than fixing 72 call sites when Credo strict mode was enabled (01-03) — a real reduction in strictness, not a clean win; re-enable with a tuned threshold if a future phase wants it back | open |  | 2026-09-16T03:17:55.224Z |  |
| 4 | 01 | unmet-truth | .credo.exs |  | 01-03's acceptance criterion 'grep -c DuplicatedCode .credo.exs == 1' cannot be literally satisfied: count is 2 because Credo's own stock-template comment at line ~87 predates this plan and was deliberately left untouched rather than deleted just to satisfy a grep | open |  | 2026-09-16T03:17:55.306Z |  |
| 5 | 01 | deviation | lib/commanded/transformers/base_transformer.ex |  | FOUND-18: create_module/4 with explicit [:file, :line] exists and is unit-tested, but is wired into NONE of the nine real create_module/3 call sites (01-01 Task 2 forbade touching them) — plan 01-01's must-have (a deliberate error names the DSL declaration's file) is not demonstrable end to end until 01-04 wires those call sites or a gap-closure plan does. Do not rubber-stamp at phase verification. | fixed |  | 2026-09-16T03:17:55.387Z | 2026-10-20T03:31:33.649Z |
| 6 | 01 | deviation | mix.exs |  | spark 2.7.2's Igniter-based spark.cheat_sheets task writes documentation/dsls/DSL-<Module>.md, not cheatsheets/<Module>.cheatmd; mix.exs's docs() extras/groups_for_extras still reference the committed cheatsheets/AshCommanded.Resource.Dsl.cheatmd file by hand-substituted content, not tool-regenerated. Predates 01-04; discovered while executing Task 2. | open |  | 2026-09-16T07:39:58.250Z |  |
| 7 | 01 | todo | lib/ash_commanded/parameter_transformer.ex | 191 | WR-04 deferred: apply_transform/2's :compute/:transform/:default/:custom clauses rescue _ -> params, discarding any exception raised by a consumer-supplied transform function with no log and no error return; a broken transform silently yields a record with a stale or missing field | open |  | 2026-10-20T03:40:37.803Z |  |
| 8 | 01 | todo | README.md, documentation/, cheatsheets/ |  | Stale pre-move namespace documentation drift: 65 occurrences of AshCommanded.Commanded.* or AshCqrs.* across 13 files (README.md, 11 files under documentation/, cheatsheets/AshCqrs.Commanded.Dsl.cheatmd), measured after plan 01-09's corrections. lib/ and test/ are clean, so this is documentation left behind by the D-13 namespace move rather than a live code defect. Deferred to Phase 7 (Documentation, Packaging and the End-to-End Example), whose goal is documentation in which no claim outruns the code and whose success criterion 4 regenerates the committed cheatsheets. No DOCS-0x requirement names module-path drift specifically, so the owner is the phase's stated goal, not a fabricated requirement citation. Contrast the deleted CollectParameterTransforms/CollectParameterValidations: no phase owned those and transform_params/validate_params appear nowhere in REQUIREMENTS.md, so a citation naming a live phase would have described work that phase does not contain. That distinction is why this deferral is legitimate and that citation was refused. | open |  | 2026-10-20T03:51:46.992Z |  |
| 9 | 01 | deviation | lib/ash_commanded/resource/transformers/ |  | Plan 01-09 removed the implementation-shaped code for parameter transformation and validation (CollectParameterTransforms and CollectParameterValidations) without providing the DSL surface the documentation previously implied. The command entity declares no nested entities, so if the capability is wanted it must return as a requirement with a real DSL entity, not as another hardcoded stub. The public functions ParameterTransformer.transform_params/2 and ParameterValidator.validate_params/2 remain documented, tested and directly callable. | open |  | 2026-10-20T03:51:46.992Z |  |
| 10 | 01 | deviation | test/support/parity/parity_widget.ex |  | 01-11 Task 3: the parity fixture's create action gained one optional argument (:source, :string, allow_nil?: true) so Ash's generated input/1 does not emit the literal 'key in []' that Elixir 1.20 warns about. The plan attributed that warning to GenerateAggregateModule, but the expression is emitted by Ash, so the fixture is the only non-suppression place to fix it. No @compile suppression was added. Approved by a human at 01-11 Task 4's blocking-human checkpoint. | open |  | 2026-10-20T18:52:15.783Z |  |
| 11 | 01 | unrun-verify | .github/workflows/ci.yml |  | Three-leg CI observation not yet made: the workflow now pairs Elixir 1.20.4 with OTP 28.5.0.8, but no GitHub Actions run exists for the branch (it is unpushed). FOUND-16 stays unclaimed until a human observes all three legs green and records the run in 01-CI-EVIDENCE.md. | open |  | 2026-10-20T20:27:14.484Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "01",
    "file": "lib/commanded/snapshot_adapter.ex",
    "line": null,
    "description": "Plan required unconditional @behaviour Commanded.Aggregates.Aggregate.Snapshotter; that module does not exist anywhere in commanded 1.4.11 (verified against deps/commanded), so the behaviour was removed entirely instead of made unconditional",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-14T00:27:47.341Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "todo",
    "phase": "01",
    "file": "lib/commanded/transformers/generate_event_handler_modules.ex",
    "line": 95,
    "description": "Generated execute_action/2 calls Ash.run_action/3, which does not exist (Ash.run_action/2 takes an ActionInput). Never exercised at runtime by any test; correct fix requires branching on the target action's real type",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-14T00:27:47.407Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "01",
    "file": ".credo.exs",
    "line": null,
    "description": "Design.AliasUsage moved to disabled: rather than fixing 72 call sites when Credo strict mode was enabled (01-03) — a real reduction in strictness, not a clean win; re-enable with a tuned threshold if a future phase wants it back",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-16T03:17:55.224Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unmet-truth",
    "phase": "01",
    "file": ".credo.exs",
    "line": null,
    "description": "01-03's acceptance criterion 'grep -c DuplicatedCode .credo.exs == 1' cannot be literally satisfied: count is 2 because Credo's own stock-template comment at line ~87 predates this plan and was deliberately left untouched rather than deleted just to satisfy a grep",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-16T03:17:55.306Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "01",
    "file": "lib/commanded/transformers/base_transformer.ex",
    "line": null,
    "description": "FOUND-18: create_module/4 with explicit [:file, :line] exists and is unit-tested, but is wired into NONE of the nine real create_module/3 call sites (01-01 Task 2 forbade touching them) — plan 01-01's must-have (a deliberate error names the DSL declaration's file) is not demonstrable end to end until 01-04 wires those call sites or a gap-closure plan does. Do not rubber-stamp at phase verification.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-16T03:17:55.387Z",
    "resolved_at": "2026-10-20T03:31:33.649Z"
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "01",
    "file": "mix.exs",
    "line": null,
    "description": "spark 2.7.2's Igniter-based spark.cheat_sheets task writes documentation/dsls/DSL-<Module>.md, not cheatsheets/<Module>.cheatmd; mix.exs's docs() extras/groups_for_extras still reference the committed cheatsheets/AshCommanded.Resource.Dsl.cheatmd file by hand-substituted content, not tool-regenerated. Predates 01-04; discovered while executing Task 2.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-16T07:39:58.250Z",
    "resolved_at": null
  },
  {
    "id": 7,
    "kind": "todo",
    "phase": "01",
    "file": "lib/ash_commanded/parameter_transformer.ex",
    "line": 191,
    "description": "WR-04 deferred: apply_transform/2's :compute/:transform/:default/:custom clauses rescue _ -> params, discarding any exception raised by a consumer-supplied transform function with no log and no error return; a broken transform silently yields a record with a stale or missing field",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-20T03:40:37.803Z",
    "resolved_at": null,
    "milestone": "v0.3"
  },
  {
    "id": 8,
    "kind": "todo",
    "phase": "01",
    "file": "README.md, documentation/, cheatsheets/",
    "line": null,
    "description": "Stale pre-move namespace documentation drift: 65 occurrences of AshCommanded.Commanded.* or AshCqrs.* across 13 files (README.md, 11 files under documentation/, cheatsheets/AshCqrs.Commanded.Dsl.cheatmd), measured after plan 01-09's corrections. lib/ and test/ are clean, so this is documentation left behind by the D-13 namespace move rather than a live code defect. Deferred to Phase 7 (Documentation, Packaging and the End-to-End Example), whose goal is documentation in which no claim outruns the code and whose success criterion 4 regenerates the committed cheatsheets. No DOCS-0x requirement names module-path drift specifically, so the owner is the phase's stated goal, not a fabricated requirement citation. Contrast the deleted CollectParameterTransforms/CollectParameterValidations: no phase owned those and transform_params/validate_params appear nowhere in REQUIREMENTS.md, so a citation naming a live phase would have described work that phase does not contain. That distinction is why this deferral is legitimate and that citation was refused.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-20T03:51:46.992Z",
    "resolved_at": null,
    "milestone": "v0.3"
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "01",
    "file": "lib/ash_commanded/resource/transformers/",
    "line": null,
    "description": "Plan 01-09 removed the implementation-shaped code for parameter transformation and validation (CollectParameterTransforms and CollectParameterValidations) without providing the DSL surface the documentation previously implied. The command entity declares no nested entities, so if the capability is wanted it must return as a requirement with a real DSL entity, not as another hardcoded stub. The public functions ParameterTransformer.transform_params/2 and ParameterValidator.validate_params/2 remain documented, tested and directly callable.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-20T03:51:46.992Z",
    "resolved_at": null,
    "milestone": "v0.3"
  },
  {
    "id": 10,
    "kind": "deviation",
    "phase": "01",
    "file": "test/support/parity/parity_widget.ex",
    "line": null,
    "description": "01-11 Task 3: the parity fixture's create action gained one optional argument (:source, :string, allow_nil?: true) so Ash's generated input/1 does not emit the literal 'key in []' that Elixir 1.20 warns about. The plan attributed that warning to GenerateAggregateModule, but the expression is emitted by Ash, so the fixture is the only non-suppression place to fix it. No @compile suppression was added. Approved by a human at 01-11 Task 4's blocking-human checkpoint.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-20T18:52:15.783Z",
    "resolved_at": null,
    "milestone": "v0.3"
  },
  {
    "id": 11,
    "kind": "unrun-verify",
    "phase": "01",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "Three-leg CI observation not yet made: the workflow now pairs Elixir 1.20.4 with OTP 28.5.0.8, but no GitHub Actions run exists for the branch (it is unpushed). FOUND-16 stays unclaimed until a human observes all three legs green and records the run in 01-CI-EVIDENCE.md.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-20T20:27:14.484Z",
    "resolved_at": null,
    "milestone": "v0.3"
  }
]
````
