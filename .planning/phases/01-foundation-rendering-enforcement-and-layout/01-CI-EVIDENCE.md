# Phase 1 CI Evidence — FOUND-16 and the CI half of FOUND-04

**Date:** 2026-10-20
**Commit at time of pre-flight:** `729abc3` (HEAD before this plan's Task 1)
**Local toolchain at time of pre-flight:** Elixir 1.18.4, Erlang/OTP 27.3 (the canonical leg)

This is a **one-time record** of two distinct things: the toolchain pre-flight that Task 1 ran
against the live hex.pm build manifests, and — once a human has observed it — the real GitHub
Actions run that closes FOUND-16. It is not a permanent test. The permanent local gates remain
`test/ash_commanded/golden_render_test.exs`, `test/ash_commanded/golden_budget_test.exs` and the
`mix check` alias.

Nothing in this document is inferred from `.github/workflows/ci.yml` reading correctly. Presence
and internal consistency of the workflow file were already established at phase verification and
are explicitly not what Task 1 or Task 3 establishes. Task 1 establishes that the artefacts every
leg depends on exist; Task 3 records a run somebody watched.

---

## 1. Toolchain pre-flight (Task 1)

**Purpose:** rule out, before spending a run, the failure mode where `erlef/setup-beam` cannot
find a prebuilt Elixir or OTP artefact for one of the three matrix legs.

**Network availability:** available for this pre-flight. Every fetch below exited `0` and returned
a non-empty manifest, so no result in this section is an unresolved unknown.

### Manifests used

| Manifest | URL | Bytes fetched |
| --- | --- | --- |
| Elixir builds | `https://builds.hex.pm/builds/elixir/builds.txt` | 94286 |
| OTP builds (Ubuntu 24.04) | `https://builds.hex.pm/builds/otp/ubuntu-24.04/builds.txt` | 19484 |

### Runner resolution

`.github/workflows/ci.yml:26` declares `runs-on: ubuntu-latest`. The moving label was resolved to
a concrete image before choosing the OTP manifest path, because the OTP manifest is published per
image and the moving label does not appear in it. From
`https://raw.githubusercontent.com/actions/runner-images/main/README.md` (fetched 2026-10-20),
verbatim:

```text
| Ubuntu 24.04<br>![Endpoint Badge](...) | x64 | `ubuntu-latest` or `ubuntu-24.04` | [ubuntu-24.04] |
```

So `ubuntu-latest` currently designates Ubuntu 24.04, and the OTP manifest path above is the one
the setup action reads for this workflow.

### Elixir lookups — key shape `v<full-version>-otp-<otp-major>`

The Elixir key carries the full Elixir version but only the OTP **major**. Assertion command and
result:

```text
$ for v in 1.18.4 1.19.6 1.20.4; do n=$(grep -c "^v${v}-otp-27 " /tmp/ash_commanded_elixir_builds.txt); echo "${v} ${n}"; done
1.18.4 1
1.19.6 1
1.20.4 1
$ echo $?
0
```

Exactly one match per leg — not merely at least one — so a loose prefix match sweeping in every
patch release would have been visible rather than passing. Verbatim matching lines:

```text
v1.18.4-otp-27 7b20c281d521aa7aa2ad2baa1e9ae6c579d79d0c 2025-08-04T12:52:12Z 98257c51bb8d0042c417638b4a109ce073b7044e60550887dfde5223cdea9c93
v1.19.6-otp-27 915d6dca16268e17605aaeb96ed5a1484f440703 2026-08-28T10:21:44Z 788fce40bb959a68c6e4e3cf80b8b7f904aa80ee891f98537ea74c24ca42a4ef
v1.20.4-otp-27 759443e724f55bf58e71c0603644e99058918d52 2026-08-28T10:07:51Z 4389f216eec086b34a08d70a3eb0a649d00e6631987d1cbb649a2f81092f034c
```

### OTP lookups — key shape `OTP-<full-version>`

All three matrix legs declare `otp: "27.3"` (`.github/workflows/ci.yml:42`, `:45`, `:53`), so the
key is identical across the three lookups. The OTP key carries the **full** OTP version, unlike
the Elixir key. Assertion command and result:

```text
$ n=$(grep -c "^OTP-27\.3 " /tmp/ash_commanded_otp_ubuntu_24_04_builds.txt); echo "count=${n}"
count=1
```

Verbatim matching line:

```text
OTP-27.3 05737d130706c7189a8e6750d9c2252d2cc7987e 2025-03-05T10:48:18Z 81bd76d88adfd8a81c3b0cf9aae766779d1e316b9c2f2dbfc17bd22cd5a62833
```

The six lookups therefore are: three Elixir keys (`v1.18.4-otp-27`, `v1.19.6-otp-27`,
`v1.20.4-otp-27`), each matching exactly once; and three OTP lookups (`OTP-27.3` for each leg),
each matching exactly once in the Ubuntu 24.04 manifest.

### Local version agreement

| Source | Verbatim | Minor series |
| --- | --- | --- |
| `.github/workflows/ci.yml:41-42` canonical leg | matrix entry `elixir: "1.18.4"` / `otp: "27.3"` | 1.18 |
| `test/test_helper.exs:10` | `canonical_elixir_version = "1.18"` | 1.18 |
| `.tool-versions:1` | `elixir 1.18.4-otp-27` | 1.18 |
| `.tool-versions:2` | `erlang 27.3` | — |

All three name the same minor series (1.18). `mix.exs:20` declares:

```elixir
elixir: "~> 1.18 or ~> 1.19 or ~> 1.20",
```

and that requirement admits all three matrix versions, checked with `Version.match?/2` rather than
asserted from reading:

```text
$ elixir -e 'req = "~> 1.18 or ~> 1.19 or ~> 1.20"; for v <- ["1.18.4", "1.19.6", "1.20.4"], do: IO.puts("#{v} => #{Version.match?(v, req)}")'
1.18.4 => true
1.19.6 => true
1.20.4 => true
$ echo $?
0
```

### Pre-flight conclusion

Every matrix leg has a prebuilt Elixir artefact under its declared key, and OTP 27.3 has a
prebuilt artefact for the concrete image `ubuntu-latest` currently designates. The local version
story is internally consistent. A toolchain-resolution failure is ruled out as the cause of a
first-run failure.

What this does **not** establish: that the workflow has run, that Actions is enabled on whichever
remote receives the branch, or that `mix check` passes on the non-canonical Elixir minors. Those
are Task 2's observation.

---

## 2. Observed run (Task 2 — pending)

**Status: not yet observed. No run has been claimed.**

The working branch (`fix-application-generation`) is pushed to neither configured remote
(`origin`, `accountex`), so no GitHub Actions run can exist yet. Task 2 is a
`blocking-human` checkpoint: a human must push the branch and report the run back.

To be appended here, verbatim, once observed:

- run identifier or URL and the commit it ran against
- per-leg conclusions for Elixir 1.18.4, 1.19.6 and 1.20.4 (all OTP 27.3)
- the resolved Elixir and OTP versions the setup step reported on each leg
- the three ExUnit summary lines including excluded counts
- which leg ran the golden text diff and which excluded it (`test/test_helper.exs` computes the
  exclusion from the running Elixir version, not from any CI-side flag)
- explicit evidence that Dialyzer and docs output appeared, proving `mix check` did not
  short-circuit before the last steps of the alias
- the `mix usage_rules.sync --check` result on every leg

Until that section is filled from an observed run, FOUND-16 and the CI half of FOUND-04 remain
**behaviour-unverified**.
