# Structural Clone Detection Report (FOUND-11, ROADMAP Phase 1 Success Criterion 4)

**Tool:** `ex_dna` 1.5.4 (hex.pm, MIT, `github.com/elixir-vibe/ex_dna`) — human-verified legitimacy
checkpoint approved this version, the `plugins: [{ExDNA.Credo, []}]` registration key, and the
`ExDNA.Credo` check module name during 01-03's execution (resumed after the checkpoint).

**Scope:** `lib/` only, per FOUND-11's wording ("runs across generator modules") and ROADMAP.md's
Phase 1 success criterion 4 ("across `lib/`"). `ExDNA.Credo`'s default `paths` param already
scopes to `lib/` (`ExDNA.Config.default(:paths)`), so no extra config was needed for that scope.

## How to regenerate this report

```bash
# The structural clone check (default config, scoped to lib/):
mix ex_dna lib/

# The same check as it participates in the real `mix credo`/`mix check` run
# (D-01-suppressed findings will not appear here; see "What the disables hide" below):
mix credo

# The built-in comparison (temporarily move Credo.Check.Design.DuplicatedCode from
# `disabled:` to `enabled:` in .credo.exs, and comment out the `plugins:` / `{ExDNA.Credo, []}`
# lines, then run `mix credo`; revert both edits afterward — do not commit the built-in check
# as enabled, per the "Coexistence" note below):
mix credo
```

## Raw output — `mix ex_dna lib/` (ex_dna 1.5.4, default config)

```text
ExDNA — code duplication report

── lib/commanded/verifiers (2 clones, 98 nodes)

[I]  #1  54 nodes
  lib/commanded/verifiers/validate_command_names.ex:38
  lib/commanded/verifiers/validate_event_names.ex:38

    defp find_duplicates(list) do
      list
      |> Enum.reduce({%{}, []}, fn item, {counts, duplicates} ->
        new_counts = Map.update(counts, item, 1, &(&1 + 1))

        if new_counts[item] > 1 && item not in duplicates do
          {new_counts, [item | duplicates]}
        else
    … (+5 lines)

  → Extract: defp shared_find_duplicates()
    lib/commanded/verifiers/validate_command_names.ex:38 → shared_find_duplicates()
    lib/commanded/verifiers/validate_event_names.ex:38 → shared_find_duplicates()


[I]  #3  44 nodes
  lib/commanded/verifiers/validate_event_handler_events.ex:78
  lib/commanded/verifiers/validate_projection_events.ex:56

    valid_events_list =
      case valid_event_names do
        [] ->
          "No events are defined in #{inspect(resource_module)}."

        events ->
          valid_list = Enum.map_join(events, "\n", &"  - #{inspect(&1)}")
          "The following events are defined in #{inspect(resource_module)}:
    … (+3 lines)

  → Extract: defp duplicated_block()
    lib/commanded/verifiers/validate_event_handler_events.ex:78 → duplicated_block()
    lib/commanded/verifiers/validate_projection_events.ex:56 → duplicated_block()


── lib/commanded/transformers (2 clones, 86 nodes)

[I]  #2  46 nodes
  lib/commanded/transformers/generate_aggregate_module.ex:514
  lib/commanded/transformers/generate_aggregate_module.ex:483

    case AshCommanded.Commanded.CommandActionMapper.map_to_action(
           command,
           resource_module,
           action_name,
           action_opts
         ) do
      {:ok, result} ->
        event_data = Map.from_struct(command)
    … (+13 lines)

  → Extract: defp handle_map_to_action()
    lib/commanded/transformers/generate_aggregate_module.ex:514 → handle_map_to_action()
    lib/commanded/transformers/generate_aggregate_module.ex:483 → handle_map_to_action()


[II] #4  40 nodes
  lib/commanded/transformers/generate_event_handler_modules.ex:341
  lib/commanded/transformers/generate_projector_modules.ex:314

    quote do
      def handle(%unquote(event_module){} = event, metadata) do
        results = [unquote_splicing(handler_impls)]

        case Enum.filter(results, fn
               {:error, _} -> true
               _ -> false
             end) do
    … (+5 lines)

  → Extract: defp duplicated_block(arg0, arg1)
    lib/commanded/transformers/generate_event_handler_modules.ex:341 → duplicated_block(metadata, handler_impls)
    lib/commanded/transformers/generate_projector_modules.ex:314 → duplicated_block(v_metadata, projection_handlers)

────────────────────────────────────────────────────────────────
  Files analyzed:     55
  Clones found:       4 (3 exact, 1 renamed)
  Duplicated lines:   ~116

  Detection time:     84ms

** (Mix) ExDNA found 4 clone(s)
```

## Raw output — `mix credo` with `Credo.Check.Design.DuplicatedCode` temporarily enabled instead

(Built-in check, config: defaults, scanning the full `included:` set — `lib/`, `test/`, etc. —
not restricted to `lib/` the way `ExDNA.Credo`'s default is.)

```text
Checking 119 source files (this might take a while) ...

  Software Design
┃
┃ [D] ↑ Duplicate code found in test/ash_commanded/golden_render_test.exs:73 (mass: 63).
┃       lib/mix/tasks/ash_commanded.dump.ex:346 #(Mix.Tasks.AshCommanded.Dump.diff_text)
┃ [D] ↑ Duplicate code found in lib/commanded/verifiers/validate_event_handler_events.ex:71 (mass: 42).
┃       lib/commanded/verifiers/validate_projection_events.ex:49 #(AshCommanded.Commanded.Verifiers.ValidateProjectionEvents.build_error_message)
┃ [D] ↑ Duplicate code found in lib/commanded/verifiers/validate_projection_events.ex:49 (mass: 42).
┃       lib/commanded/verifiers/validate_event_handler_events.ex:71 #(AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents.build_error_message)
┃ [D] ↑ Duplicate code found in lib/commanded/transformers/generate_aggregate_module.ex:477 (mass: 45).
┃       lib/commanded/transformers/generate_aggregate_module.ex:508 #(AshCommanded.Commanded.Transformers.GenerateAggregateModule.generate_execute_functions)
┃ [D] ↑ Duplicate code found in lib/mix/tasks/ash_commanded.dump.ex:346 (mass: 63).
┃       test/ash_commanded/golden_render_test.exs:73 #(AshCommanded.GoldenRenderTest.diff_text)
┃ [D] ↑ Duplicate code found in lib/commanded/verifiers/validate_command_names.ex:32 (mass: 51).
┃       lib/commanded/verifiers/validate_event_names.ex:32 #(AshCommanded.Commanded.Verifiers.ValidateEventNames.find_duplicates)
┃ [D] ↑ Duplicate code found in lib/commanded/verifiers/validate_event_names.ex:32 (mass: 51).
┃       lib/commanded/verifiers/validate_command_names.ex:32 #(AshCommanded.Commanded.Verifiers.ValidateCommandNames.find_duplicates)

615 mods/funs, found 7 software design suggestions.
```

## Raw output — `mix credo` with `ExDNA.Credo` registered (this repository's real, committed config)

```text
Checking 119 source files (this might take a while) ...

  Software Design
┃
┃ [D] ↑ Duplicate code (exact, mass: 44) also in lib/commanded/verifiers/validate_event_handler_events.ex:71. → extract duplicated_block()
┃       lib/commanded/verifiers/validate_projection_events.ex:49 #(AshCommanded.Commanded.Verifiers.ValidateProjectionEvents.build_error_message)
┃ [D] ↑ Duplicate code (exact, mass: 44) also in lib/commanded/verifiers/validate_projection_events.ex:49. → extract duplicated_block()
┃       lib/commanded/verifiers/validate_event_handler_events.ex:71 #(AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents.build_error_message)
┃ [D] ↑ Duplicate code (renamed, mass: 40) also in lib/commanded/transformers/generate_event_handler_modules.ex:334. → extract duplicated_block(arg0, arg1)
┃       lib/commanded/transformers/generate_projector_modules.ex:307 #(AshCommanded.Commanded.Transformers.GenerateProjectorModules.build_event_handler)
┃ [D] ↑ Duplicate code (renamed, mass: 40) also in lib/commanded/transformers/generate_projector_modules.ex:307. → extract duplicated_block(arg0, arg1)
┃       lib/commanded/transformers/generate_event_handler_modules.ex:334 #(AshCommanded.Commanded.Transformers.GenerateEventHandlerModules.build_event_handler)
┃ [D] ↑ Duplicate code (exact, mass: 46) also in lib/commanded/transformers/generate_aggregate_module.ex:477. → extract handle_map_to_action()
┃       lib/commanded/transformers/generate_aggregate_module.ex:508 #(AshCommanded.Commanded.Transformers.GenerateAggregateModule.generate_execute_functions)
┃ [D] ↑ Duplicate code (exact, mass: 46) also in lib/commanded/transformers/generate_aggregate_module.ex:508. → extract handle_map_to_action()
┃       lib/commanded/transformers/generate_aggregate_module.ex:477 #(AshCommanded.Commanded.Transformers.GenerateAggregateModule.generate_execute_functions)
┃ [D] ↑ Duplicate code (exact, mass: 54) also in lib/commanded/verifiers/validate_command_names.ex:32. → extract shared_find_duplicates()
┃       lib/commanded/verifiers/validate_event_names.ex:32 #(AshCommanded.Commanded.Verifiers.ValidateEventNames.find_duplicates)
┃ [D] ↑ Duplicate code (exact, mass: 54) also in lib/commanded/verifiers/validate_event_names.ex:32. → extract shared_find_duplicates()
┃       lib/commanded/verifiers/validate_command_names.ex:32 #(AshCommanded.Commanded.Verifiers.ValidateCommandNames.find_duplicates)

615 mods/funs, found 8 software design suggestions.
```

(This is the run that landed in this commit BEFORE the D-01 suppression pass below was applied.
After the suppression pass, `mix credo`/`mix check` are green — see "What the disables hide".)

## Comparison — what `ExDNA.Credo` finds that the built-in `DuplicatedCode` does not

| # | Pair | Type | Mass | Found by ExDNA.Credo | Found by built-in DuplicatedCode |
| --- | ------ | ------ | ------ | :---: | :---: |
| 1 | `validate_command_names.ex:38` (`shared_find_duplicates`) ↔ `validate_event_names.ex:38` | Type-I (exact) | 51–54 | Yes | Yes |
| 2 | `validate_event_handler_events.ex:78` (`build_error_message`) ↔ `validate_projection_events.ex:56` | Type-I (exact) | 42–44 | Yes | Yes |
| 3 | `generate_aggregate_module.ex:483` ↔ `generate_aggregate_module.ex:514` (`handle_map_to_action`, self-clone) | Type-I (exact) | 45–46 | Yes | Yes |
| 4 | `generate_event_handler_modules.ex:341` (`build_handler_module_ast`) ↔ `generate_projector_modules.ex:314` (`build_event_handler`) | **Type-II (renamed variables)** | 40 | **Yes** | **No** |
| 5 | `mix/tasks/ash_commanded.dump.ex:346` (`diff_text`) ↔ `test/ash_commanded/golden_render_test.exs:73` | Type-I (exact) | 63 | No (`test/` out of `ExDNA.Credo`'s default `lib/`-only scope) | Yes |

**The clone pair the built-in check does not report (ROADMAP SC4's literal wording):** pair #4 —
`generate_event_handler_modules.ex`'s `build_handler_module_ast/5` and
`generate_projector_modules.ex`'s `build_event_handler/5` share a 40-node dispatch/error-handling
`quote` block, differing only in two renamed local variables (`metadata`/`v_metadata`,
`handler_impls`/`projection_handlers`). `Credo.Check.Design.DuplicatedCode` performs Type-I
(exact) matching only and does not normalize variable names, so it cannot see this pair at all —
confirmed by pair #4's absence from the built-in check's raw output above, run against the exact
same tree. This is exactly the capability gap FOUND-11 exists to close: two independently-written
event-consumption generators (event handlers, projectors) drifted into the same dispatch shape,
and only a renamed-variable-aware structural check surfaces it.

**Pair #5 runs the other way** (built-in finds it, `ExDNA.Credo` does not by default): it sits in
`test/`, outside `ExDNA.Credo`'s default `paths` scope (`lib/` only). This is a deliberate, not
accidental, scope choice — FOUND-11's wording and ROADMAP.md's success criterion 4 both say
"across `lib/`", so `ExDNA.Credo`'s stock default is exactly the required scope and was left
unconfigured (`{ExDNA.Credo, []}`, no `paths:` override) rather than widened to include `test/`.

## What the disables hide (D-01 suppression pass)

Per FOUND-11's own wording — "runs across generator modules and reports clones," not "fails the
build" — and per D-01/D-02 (the same phase-cited suppression mechanism task 2 introduced for
FOUND-07/09/10), every file `ExDNA.Credo` newly flagged now carries a
`# credo:disable-for-this-file ExDNA.Credo` header with a `# gsd-disable-until-phase: N` citation,
so `mix check` stays green rather than turning permanently red until Phase 2/4/5 land:

| Clone pair | Files | `gsd-disable-until-phase` |
| --- | --- | --- |
| #1 | `validate_command_names.ex`, `validate_event_names.ex` | 2 (Commands and Events) |
| #2 | `validate_event_handler_events.ex`, `validate_projection_events.ex` | 5 (Projections, Event Handlers and Process Managers) |
| #3 | `generate_aggregate_module.ex` (self-clone) | 4 (Aggregates) |
| #4 | `generate_event_handler_modules.ex`, `generate_projector_modules.ex` | 5 (Projections, Event Handlers and Process Managers) |

The suppressions hide these four findings from `mix check`'s exit code only — this report is the
mechanism that keeps them visible until each cited phase's rewrite removes the duplication (and
the disable) at the source, per D-01's existing pattern for FOUND-07/09/10.

## Coexistence with the built-in `DuplicatedCode` check

`Credo.Check.Design.DuplicatedCode` was **already disabled** in `.credo.exs`'s `disabled:` list
before this plan touched it (01-CONTEXT.md's own "Correction" section: an earlier draft of that
file claimed it was enabled, which was wrong — it sat inside the `disabled:` block the whole
time). Adopting `ExDNA.Credo` is therefore a pure addition, not a swap, exactly as
01-RESEARCH.md's Open Question 6 anticipated.

Registering the plugin via `plugins: [{ExDNA.Credo, []}]` alone was **not sufficient** to make the
check run, despite hexdocs.pm/ex_dna's README presenting it as the recommended path — this was
discovered live during this task, not assumed. `ExDNA.Credo.init/1` registers its own default
config (`{ExDNA.Credo, []}` in `checks: extra:`, `DuplicatedCode` disabled) via
`Credo.Plugin.register_default_config/2`, but `Credo.ConfigFile.merge_checks/2` has a merge
clause that fires whenever the *consuming* `.credo.exs` (this project's, loaded after the
plugin's default per that function's own moduledoc) declares its own `checks: enabled:` list —
which this file already did, long before ex_dna. That clause discards the plugin's `extra:`
contribution entirely rather than merging it in. hexdocs.pm/ex_dna's README documents exactly
this as the documented fallback ("Or add directly to the `:enabled` checks list"), so `.credo.exs`
now carries **both** the `plugins:` registration and an explicit `{ExDNA.Credo, []}` entry in
`checks: enabled:` — for any project with a real, non-empty `enabled:` list (the overwhelmingly
common shape, and this project's own shape since before ex_dna), both lines are required; the
plugin registration alone silently runs nothing.

`Credo.Check.Design.DuplicatedCode`'s entry stays in `.credo.exs`'s `disabled:` list, now with a
comment noting it is redundant with (not in tension with) the plugin's own auto-disable — kept as
explicit, human-readable config rather than relying solely on the plugin's implicit behavior.

## Package version and installation

- `ex_dna` `~> 1.5.4` (resolved: `1.5.4`), `only: [:dev, :test], runtime: false` in `mix.exs`
  (T-01-SC: confined to dev/test, never reaches a consumer's compiled application).
- `mix.lock` records the resolved version and checksum.
