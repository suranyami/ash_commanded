defmodule AshCommanded.Domain.Info do
  @moduledoc """
  The single lookup point for `AshCommanded.Domain.Dsl`'s DSL state (rewrite rule 6,
  PROJECT.md Constraints).

  `AshCommanded.Domain.Dsl` declares `sections: []` today — see its own moduledoc: it
  only `imports: [AshCommanded.Resource.Dsl]` so the `commanded do application do ... end
  end` block parses on an `Ash.Domain`, without contributing a section of its own.
  `Spark.InfoGenerator` therefore currently generates zero accessors here — an accurate
  reflection of what this extension declares, not a bug in this module. This establishes
  the `.Info` convention FOUND-17 requires for the domain tree now, so APP-11 (Phase 3),
  which gives the domain its own `:application` section, only has to extend the
  `sections:` list below rather than create this module or reshuffle directories.
  """

  use Spark.InfoGenerator,
    extension: AshCommanded.Domain.Dsl,
    sections: [:commanded]
end
