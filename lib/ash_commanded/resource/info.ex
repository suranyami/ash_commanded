defmodule AshCommanded.Resource.Info do
  @moduledoc """
  The single lookup point for `AshCommanded.Resource.Dsl`'s DSL state (rewrite rule 6,
  PROJECT.md Constraints).

  Generated entirely by `Spark.InfoGenerator` from the extension's own declared section
  tree — one `use` line replaces N hand-written per-section getter functions and stays in
  sync with the DSL's actual shape automatically, because it reads the shape rather than
  duplicating it. `AshCommanded.Resource.Dsl` declares a single top-level `:commanded`
  section holding `:commands`, `:events`, `:projections`, `:event_handlers` and
  `:application` as nested sections, so `sections: [:commanded]` below walks the whole
  tree and generates an entity accessor (e.g. `commanded_commands/1`) or an options
  accessor (e.g. `commanded_application_options/1`) for every one of them.

  Populating this module with component-specific, hand-named accessors (e.g. a plain
  `commands/1` alias) is later-phase work — CMD-08 (Phase 2), APP-11 (Phase 3), AGG-09
  (Phase 4) — this plan only establishes the module and the convention so those phases
  do not have to create it or reshuffle directories first.
  """

  use Spark.InfoGenerator,
    extension: AshCommanded.Resource.Dsl,
    sections: [:commanded]
end
