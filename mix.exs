defmodule AshCommanded.MixProject do
  use Mix.Project

  @version "0.2.0"
  @description "CQRS pattern implementation for Ash Framework resources using Commanded"
  @source_url "https://github.com/accountex-org/ash_commanded"

  def project do
    [
      app: :ash_commanded,
      version: @version,
      # FOUND-16: current Elixir/OTP release plus the previous two minors
      # (PROJECT.md Constraints), verified against the real release list on 2026-09-16 via
      # `mise ls-remote elixir` (current: 1.20.x; previous two: 1.19.x, 1.18.x) — re-verify
      # against the real release list, not this comment, before assuming these are still
      # current. `~> 1.18` alone (the prior declaration) matches ONLY 1.18.x and would reject
      # the 1.19/1.20 CI legs at `mix deps.get`; this widens the ceiling to match all three
      # while keeping the floor exactly where it was tightened to (D-12's canonical golden
      # version, `test/test_helper.exs`, stays 1.18 — the oldest of the three, not the newest).
      elixir: "~> 1.18 or ~> 1.19 or ~> 1.20",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: @description,
      package: package(),

      # Docs
      name: "AshCommanded",
      docs: docs(),

      # usage_rules (FOUND-13, dev-only): aggregates OTHER dependencies' own
      # `usage-rules.md`/sub-rule files INTO AGENTS.md's sync-managed block, delimited by
      # `<!-- usage-rules-start/end -->`. This is the opposite direction from `usage-rules.md`
      # at the repository root, which is THIS library's own hand-authored file describing
      # itself to a consumer. `:spark` and `:igniter` are the only current dependencies that
      # actually ship a `usage-rules.md` (verified against `deps/*/usage-rules.md` on disk,
      # 2026-09-16) — `:ash` and `:commanded`, the other two frameworks this library is built
      # on, do not ship one in the vendored versions pinned here, and listing a package with
      # neither a main file nor sub-rules is a hard resolution error
      # (`deps/usage_rules/lib/mix/tasks/usage_rules.sync.ex`'s `resolve_named_usage_rules/6`),
      # not a silent skip. `mix usage_rules.sync --check` (wired into CI, not the `check`
      # alias — see aliases/0) fails the build the moment a synced dependency's rules drift
      # from what is committed.
      usage_rules: usage_rules(),

      # Testing
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],

      # Static analysis
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        # :mix ships callback info for `Mix.Task` and friends; without it in the PLT,
        # Dialyzer treats `mix ash_commanded.dump`'s use of Mix.Task/Mix.raise/Mix.shell as
        # unknown functions rather than actually checking them.
        #
        # :credo ships the `Credo.Check` behaviour and its support modules (SourceFile,
        # IssueMeta, Code, Execution.*); without it in the PLT, Dialyzer treats every
        # Credo.* call inside `lib/ash_commanded/credo_checks/*.ex` (01-03, FOUND-09/10) as
        # an unknown function/type rather than actually checking them.
        plt_add_apps: [:mix, :credo]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:spark, "~> 2.6"},
      {:igniter, "~> 0.5", only: [:dev, :test]},

      # Event sourcing runtime
      {:commanded, "~> 1.4"},
      {:eventstore, "~> 1.4", optional: true},
      {:commanded_eventstore_adapter, "~> 1.4", optional: true},

      # Static analysis and coverage
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # Structural clone detection (FOUND-11), pinned to the version the human-verified
      # legitimacy checkpoint confirmed (01-03). `runtime: false`, dev/test only: it executes
      # during `mix credo`/`mix ex_dna` with developer/CI privileges (T-01-SC) and must never
      # reach a consumer's compiled application.
      {:ex_dna, "~> 1.5.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:usage_rules, "~> 1.2", only: [:dev]},

      # Documentation
      {:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [:spark, :igniter]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support/parity"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Accountex"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: package_files()
    ]
  end

  # Hex's `files:` key is an include list, not an include-with-exclusions list, so listing the
  # bare `lib` directory (as this project did before 01-03) ships EVERYTHING under it. Excluding
  # `lib/ash_commanded/credo_checks/` (the FOUND-09/10 custom Credo checks, dev/test-only tooling
  # per this repository's own `credo` dep being `only: [:dev, :test]`, T-01-SC-02) requires
  # enumerating `lib/`'s real files and rejecting that one subtree instead.
  defp package_files do
    excluded_prefix = "lib/ash_commanded/credo_checks"

    lib_files =
      "lib/**/*"
      |> Path.wildcard()
      # Two things at once, both required: `File.regular?/1` drops directory entries — Hex
      # treats a bare directory path in `files:` as "include everything under it," which would
      # silently re-include the excluded subtree's files via its own parent directory entry
      # (`lib/ash_commanded/credo_checks` itself) even after this filter rejects the files
      # directly. Matching on `excluded_prefix` (exact, or with a trailing "/") excludes the
      # subtree regardless of that directory-entry re-inclusion behaviour.
      |> Enum.reject(fn path ->
        not File.regular?(path) or path == excluded_prefix or
          String.starts_with?(path, excluded_prefix <> "/")
      end)

    lib_files ++ ~w(mix.exs README.md LICENSE .formatter.exs usage-rules.md)
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "LICENSE",
        "documentation/commands.md",
        "documentation/events.md",
        "documentation/projections.md",
        "documentation/event_handlers.md",
        "documentation/middleware.md",
        "documentation/parameter_handling.md",
        "documentation/transactions.md",
        "documentation/context_propagation.md",
        "documentation/error_handling.md",
        "documentation/routers.md",
        "documentation/application.md",
        "documentation/snapshotting.md",
        "cheatsheets/AshCommanded.Resource.Dsl.cheatmd"
      ],
      groups_for_extras: [
        Guides: [
          "documentation/commands.md",
          "documentation/events.md",
          "documentation/projections.md",
          "documentation/event_handlers.md",
          "documentation/routers.md",
          "documentation/application.md",
          "documentation/snapshotting.md"
        ],
        "Advanced Features": [
          "documentation/middleware.md",
          "documentation/parameter_handling.md",
          "documentation/transactions.md",
          "documentation/context_propagation.md",
          "documentation/error_handling.md"
        ],
        Cheatsheets: [
          "cheatsheets/AshCommanded.Resource.Dsl.cheatmd"
        ]
      ],
      groups_for_modules: [
        DSL: [
          AshCommanded.Resource.Dsl,
          AshCommanded.Domain.Dsl,
          ~r/AshCommanded.Resource.Sections/
        ],
        Transformers: [
          ~r/AshCommanded.Resource.Transformers/,
          ~r/AshCommanded.Domain.Transformers/
        ],
        Verifiers: [
          ~r/AshCommanded.Resource.Verifiers/
        ],
        Info: [
          AshCommanded.Resource.Info,
          AshCommanded.Domain.Info
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1,
      before_closing_head_tag: &before_closing_head_tag/1,
      formatters: ["html"]
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.css" integrity="sha384-Um5gpz1odJg5Z4HAmzPtgZKdTBHZdw8S29IecapCSB31ligYPhHQZMIlWLYQGVoc" crossorigin="anonymous">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.js" integrity="sha384-YNHdsYkH6gMx9y3mRkmcJ2mFUjTd0qNQQvY9VYZgQd7DcN7env35GzlmFaZ23JGp" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/contrib/auto-render.min.js" integrity="sha384-vZTG03m+2yp6N6BNi5iM4rW4oIwk5DfcNdFfxkk9ZWpDriOkXX8voJBFrAO7MpVl" crossorigin="anonymous" onload="renderMathInElement(document.body);"></script>
    """
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
            graphEl.innerHTML = svgSource;
            bindListeners && bindListeners(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp aliases do
    [
      setup: ["local.hex --force", "local.rebar --force", "deps.get", "deps.compile"],
      docs: ["docs", &copy_images/1],
      "gen.docs": ["spark.cheat_sheets", "docs"],
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshCommanded.Resource.Dsl,AshCommanded.Domain.Dsl",
      # REPO-05's dev gate, cheapest first, so a contributor gets the fast failure first.
      # CI (see .github/workflows) invokes each command as its own step rather than
      # restating an alias, so the two cannot drift (D-23).
      #
      # Runs as :dev by default (matching the `dialyzer`/`credo`/`compile --warnings-as-errors`
      # steps, which must NOT see test/support's ExUnit-only modules — Dialyzer has no :ex_unit
      # application in its PLT, so analyzing test/support under MIX_ENV=test raises spurious
      # "unknown_function" findings for ExUnit.Callbacks macros).
      #
      # The test suite is deliberately NOT in this alias. A Mix alias runs in one environment;
      # changing environment inside it requires a subprocess (`cmd MIX_ENV=test mix ...`), and
      # Mix 1.19 stopped parsing `cmd` through a shell, so `cmd MIX_ENV=test mix coveralls`
      # treated `MIX_ENV=test` as the executable and raised `:enoent`. The environment switch
      # belongs to the caller instead: `MIX_ENV=test mix coveralls` is invoked directly by CI
      # (with `MIX_ENV: test` on the step) or by the developer's shell.
      #
      # `coveralls` (not a second, separate `mix test`) runs the suite and reports coverage in
      # one pass — ExCoveralls' own task already runs ExUnit under the hood
      # (`preferred_cli_env: [coveralls: :test, ...]` above), so running both would pay for the
      # suite twice for no extra signal (01-03 strictness pass, scope addition).
      #
      # `scripts/compile_parity.sh` is likewise not in this alias: it genuinely starts two VMs
      # (one per environment), so it is not a basic Mix task and remains its own CI step.
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo",
        "dialyzer",
        "gen.docs"
      ],
      # A fast, format/compile/credo subset of `check` for local iteration — skips
      # `dialyzer` and `gen.docs`, which are the slowest steps and do not need to re-run on
      # every save (01-03 strictness pass, scope addition). Its test half is invoked directly
      # by the caller as `MIX_ENV=test mix test`, for the same reason `check` excludes the suite.
      "precommit.fast": [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo"
      ]
    ]
  end

  # Copy images after docs are generated
  defp copy_images(_) do
    # Add any image copying logic here if needed
    :ok
  end
end
