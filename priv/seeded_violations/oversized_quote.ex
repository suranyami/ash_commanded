# SEEDED VIOLATION (ROADMAP Phase 1 SC3, FOUND-07) — deliberately invalid, deliberately
# uncompiled. This fixture exists to trip the quote-block-size gate: a single `quote`
# block spanning more than 40 lines, shaped like generator SOURCE (a transformer building
# a large quoted body) rather than like rendered output. It lives under
# `priv/seeded_violations/` — on no `elixirc_paths` entry and swept by no `.credo.exs`
# `included:` glob — so it encodes this violation permanently without ever compiling or
# linting. See `test/ash_commanded/seeded_violations_test.exs`, the permanent regression
# test proving `Credo.Check.Refactor.LongQuoteBlocks` (configured at `max_line_count: 40`
# in `.credo.exs`, FOUND-07) still reports this block as exceeding the ceiling.
defmodule AshCommanded.SeededViolations.OversizedQuote do
  defp build(_command) do
    quote do
      def execute(state, command) do
        field_01 = command.field_01
        field_02 = command.field_02
        field_03 = command.field_03
        field_04 = command.field_04
        field_05 = command.field_05
        field_06 = command.field_06
        field_07 = command.field_07
        field_08 = command.field_08
        field_09 = command.field_09
        field_10 = command.field_10
        field_11 = command.field_11
        field_12 = command.field_12
        field_13 = command.field_13
        field_14 = command.field_14
        field_15 = command.field_15
        field_16 = command.field_16
        field_17 = command.field_17
        field_18 = command.field_18
        field_19 = command.field_19
        field_20 = command.field_20
        field_21 = command.field_21
        field_22 = command.field_22
        field_23 = command.field_23
        field_24 = command.field_24
        field_25 = command.field_25
        field_26 = command.field_26
        field_27 = command.field_27
        field_28 = command.field_28
        field_29 = command.field_29
        field_30 = command.field_30
        field_31 = command.field_31
        field_32 = command.field_32
        field_33 = command.field_33
        field_34 = command.field_34
        field_35 = command.field_35
        field_36 = command.field_36
        field_37 = command.field_37
        field_38 = command.field_38
        field_39 = command.field_39
        field_40 = command.field_40
        field_41 = command.field_41
        field_42 = command.field_42
        {:ok, state}
      end
    end
  end
end
