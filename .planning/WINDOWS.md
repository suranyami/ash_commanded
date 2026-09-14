---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-09-14T00:27:47.407Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | lib/commanded/snapshot_adapter.ex |  | Plan required unconditional @behaviour Commanded.Aggregates.Aggregate.Snapshotter; that module does not exist anywhere in commanded 1.4.11 (verified against deps/commanded), so the behaviour was removed entirely instead of made unconditional | open |  | 2026-09-14T00:27:47.341Z |  |
| 2 | 01 | todo | lib/commanded/transformers/generate_event_handler_modules.ex | 95 | Generated execute_action/2 calls Ash.run_action/3, which does not exist (Ash.run_action/2 takes an ActionInput). Never exercised at runtime by any test; correct fix requires branching on the target action's real type | open |  | 2026-09-14T00:27:47.407Z |  |

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
  }
]
````
