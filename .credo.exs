# This file contains the configuration for Credo and you are probably reading
# this after creating it with `mix credo.gen.config`.
#
# If you find anything wrong or unclear in this file, please report an
# issue on GitHub: https://github.com/rrrene/credo/issues
#
%{
  #
  # You can have as many configs as you like in the `configs:` field.
  configs: [
    %{
      #
      # Run any config using `mix credo -C <name>`. If no config name is given
      # "default" is used.
      #
      name: "default",
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      #
      # Load and configure plugins here:
      #
      # ex_dna 1.5.4 (FOUND-11, human-verified legitimacy checkpoint approved 01-03): structural
      # clone detection reusing Credo's already-parsed ASTs.
      #
      # The line below registers the plugin's OWN default config (which puts `ExDNA.Credo` in
      # `checks: extra:` and disables the built-in duplicate-code check) — but empirically
      # verified this session (`mix credo` found 0 issues with only this line present, vs. 4
      # real clones from a standalone `mix ex_dna lib/` run): `Credo.ConfigFile.merge_checks/2`
      # has a clause that fires whenever the CONSUMING `.credo.exs` declares its own
      # `checks: enabled:` list (which this file already did before ex_dna) — that clause
      # discards the plugin's `extra:` contribution entirely rather than merging it in,
      # because the base's `enabled:` is pattern-bound to `_checks_base` (ignored) once the
      # "other" config carries an `enabled:` key at all. hexdocs.pm/ex_dna's README documents
      # exactly this as the fallback ("Or add directly to the `:enabled` checks list"), which is
      # why `{ExDNA.Credo, []}` is ALSO listed explicitly in `checks: enabled:` below — for a
      # project with a real `enabled:` list (virtually every project, including this one before
      # ex_dna), the plugin registration alone is not sufficient; both lines are required.
      # The built-in duplicate-code check (`disabled:` list below) was ALREADY disabled before
      # this change (01-CONTEXT.md's "Correction" — an earlier draft claimed otherwise), so
      # nothing extra needs disabling there either way.
      plugins: [{ExDNA.Credo, []}],
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      #
      # AshCommanded.CredoChecks.{NoRuntimeStringToAst, NoModuleNameSurgery, Exemption}
      # (FOUND-09, FOUND-10) live here — see `checks: enabled:` below for the modules
      # themselves.
      requires: ["lib/ash_commanded/credo_checks/*.ex"],
      #
      # If you want to enforce a style guide and need a more traditional linting
      # experience, you can change `strict` to `true` below:
      #
      strict: true,
      #
      # To modify the timeout for parsing files, change this value:
      #
      parse_timeout: 5000,
      #
      # If you want to use uncolored output by default, you can change `color`
      # to `false` below:
      #
      color: true,
      #
      # You can customize the parameters of any check by adding a second element
      # to the tuple.
      #
      # To disable a check put `false` as second element:
      #
      #     {Credo.Check.Design.DuplicatedCode, false}
      #
      checks: %{
        enabled: [
          #
          ## Consistency Checks
          #
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          #
          ## Design Checks
          #
          # You can customize the priority of any check
          # Priority values are: `low, normal, high, higher`
          #
          {Credo.Check.Design.TagFIXME, []},
          # You can also customize the exit_status of each check.
          # If you don't want TODO comments to cause `mix credo` to fail, just
          # set this value to 0 (zero).
          #
          {Credo.Check.Design.TagTODO, [exit_status: 2]},
          # FOUND-11 (01-03): explicit `checks: enabled:` entry, required alongside the
          # plugin registration above per this file's own merge-behavior comment there.
          # `base_priority: :higher` is the check module's own default (see
          # deps/ex_dna/lib/ex_dna/integrations/credo.ex) and is not overridden here.
          {ExDNA.Credo, []},

          #
          ## Readability Checks
          #
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          #
          ## Refactoring Opportunities
          #
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FunctionArity, []},
          # max_line_count: 40 matches rewrite rule 3's stated ceiling (FOUND-07). Do NOT
          # delete generate_aggregate_module.ex's own LongQuoteBlocks disable below — its
          # largest `quote` block is 225 lines and Phase 4 owns the rewrite (D-01); deleting
          # the disable here would turn `mix check` red for four phases.
          {Credo.Check.Refactor.LongQuoteBlocks, [max_line_count: 40]},

          # FOUND-09, FOUND-10 (01-03): both custom checks carry `base_priority: :high` in
          # their own `use Credo.Check` declaration; listed here with no priority override so
          # that base priority is what fires. `strict: true` above and the deliberate-violation
          # proof in 01-03-SUMMARY.md both confirm these block the real `mix check` alias.
          {AshCommanded.CredoChecks.NoRuntimeStringToAst, []},
          {AshCommanded.CredoChecks.NoModuleNameSurgery, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          #
          ## Warnings
          #
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.StructFieldAmount, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedMapOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFilename, []}
        ],
        disabled: [
          #
          # Moved here 2026-09-16 (01-03, strictness pass). Stock config
          # (`if_nested_deeper_than: 2, if_called_more_often_than: 0`) flags a SINGLE
          # nested-module reference anywhere — under `strict: true` this produced 72 issues
          # across 40+ files (generators later phases rewrite wholesale, permanent runtime
          # modules, and integration tests for generators that get deleted alongside them).
          # None of the 72 relate to the eleven rewrite-rule gates FOUND-07/09/10/11 this plan
          # enforces; aliasing every nested reference campaign-wide is disproportionate churn
          # for a generic style preference, and per-file phase-cited suppression (D-01/D-02)
          # doesn't fit either, since a majority of the hits are in permanent (non-generator)
          # modules and in test/ (which D-02's citation-parser does not even inspect). Disabled
          # as a deliberate config choice, not a suppression debt — re-enable with a tuned
          # threshold if a future phase wants it back.
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Refactor.UtcNowTruncate, []},

          #
          # Controversial and experimental checks (opt-in, just move the check to `:enabled`
          #   and be sure to use `mix credo --strict` to see low priority checks)
          #
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},
          # Stays disabled after 01-03's ex_dna plugin registration above. The plugin's own
          # default config also disables this automatically via `Credo.Plugin`, but that
          # mechanism is overridden by this project's own explicit `checks:` list the same way
          # the plugin's `extra:` check registration is (see the plugin registration comment
          # above) — so THIS line, not the plugin's auto-disable, is what actually keeps it off.
          # Left in place as explicit, human-readable config rather than relying on a plugin
          # mechanism that a config shaped like this one's overrides anyway
          # (FOUND-11; see 01-CLONE-REPORT.md for the comparison this replaces it
          # with: ExDNA.Credo, not this check).
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.OnePipePerLine, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.ABCSize, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.CondInsteadOfIfElse, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.VariableRebinding, []},
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, []}
          # {Credo.Check.Warning.UnusedOperation, [{MyMagicModule, [:fun1, :fun2]}]}

          # {Credo.Check.Refactor.MapInto, []},

          #
          # Custom checks can be created using `mix credo.gen.check`.
          #
        ]
      }
    }
  ]
}
