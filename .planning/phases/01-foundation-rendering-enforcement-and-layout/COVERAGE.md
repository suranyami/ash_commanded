# API Coverage — Phase 1: Foundation

No external API integration: this phase builds internal development tooling for AshCommanded itself
(a renderer mix task, custom Credo checks, a golden-file harness, a `lib/` relocation and CI), and
consumes no external API, SDK or service.

The `api-coverage` detector returned `detected: true` on a false positive: it matched the noun `api`
against the phrase **"the Spark API surface"** in FOUND-15, which is a requirement about what
`AGENTS.md` should document, not an integration. Per the capability's own guidance — "do NOT
fabricate a matrix row for a capability that does not exist" — this reasoned declaration stands in
place of a matrix.

Dependencies added this phase (`ex_dna`) are ordinary Hex build-time dev dependencies, not
integrations with a remote service.
