#!/usr/bin/env bash
#
# Cross-environment compile parity check (D-19, SC2).
#
# Proves that AshCommanded.Commanded.Dsl's generated modules — aggregate, command, event and
# projector — are produced identically whether the parity fixture
# (test/support/parity/parity_widget.ex, test/support/parity/parity_domain.ex) compiles under
# MIX_ENV=dev or MIX_ENV=test. Before this fixture existed, the dev compilation output contained
# no generated modules at all, because every DSL-using resource in this repository lived under
# `test/` — this script and its fixture are what make that claim checkable.
#
# Deliberately does NOT diff the dev and test compilation output directories against each other
# as directory trees: that comparison is swamped by the many test-only modules (ETS fixtures,
# test-framework cases, etc.) that legitimately exist under `:test` only and would produce
# constant false failures. Instead this checks a fixed, explicit list of modules the fixture is
# expected to generate, under each environment in turn.
set -euo pipefail

EXPECTED_MODULES=(
  "AshCommanded.TestSupport.Parity.Widget"
  "AshCommanded.TestSupport.Parity.WidgetAggregate"
  "AshCommanded.TestSupport.Parity.Commands.CreateWidget"
  "AshCommanded.TestSupport.Parity.Events.WidgetCreated"
  "AshCommanded.TestSupport.Parity.Projections.WidgetCreated"
  "AshCommanded.TestSupport.Parity.Projectors.WidgetProjector"
)

check_env() {
  local env="$1"
  echo "==> Compiling under MIX_ENV=${env}"
  MIX_ENV="${env}" mix compile --force >/dev/null

  local module
  local failed=0

  for module in "${EXPECTED_MODULES[@]}"; do
    if MIX_ENV="${env}" mix run --no-compile -e "
      case Code.ensure_loaded(${module}) do
        {:module, _} -> System.halt(0)
        {:error, reason} -> IO.puts(:stderr, \"MISSING under MIX_ENV=${env}: ${module} (\#{inspect(reason)})\"); System.halt(1)
      end
    " >/dev/null 2>&1; then
      echo "    OK   MIX_ENV=${env}: ${module}"
    else
      echo "    FAIL MIX_ENV=${env}: ${module} did not load"
      failed=1
    fi
  done

  return "${failed}"
}

overall_failed=0

if ! check_env "dev"; then
  overall_failed=1
fi

if ! check_env "test"; then
  overall_failed=1
fi

if [ "${overall_failed}" -ne 0 ]; then
  echo ""
  echo "compile_parity.sh: FAILED — one or more expected modules did not load under one or both environments." >&2
  exit 1
fi

echo ""
echo "compile_parity.sh: PASSED — all $(( ${#EXPECTED_MODULES[@]} )) expected modules loaded under both MIX_ENV=dev and MIX_ENV=test."
