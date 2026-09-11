# Technology Stack

<!-- refreshed: 2026-09-11 -->

**Analysis Date:** 2026-09-11

## Languages

**Primary:**
- Elixir 1.18.4 - Main implementation language for DSL extension

**Secondary:**
- Markdown - Documentation

## Runtime

**Environment:**
- Erlang/OTP 27.3 - Runtime environment (implicit for Elixir)

**Package Manager:**
- Mix 1.18.4 - Elixir package manager
- Lockfile: `mix.lock` (present)

## Frameworks

**Core:**
- Ash Framework 3.5.8 (~> 3.0) - Resource declaration and action framework that AshCommanded extends
- Spark 2.3.5 (~> 2.3) - DSL construction and transformation framework
- Commanded 1.4.8 - CQRS/Event Sourcing library (peer dependency, not in mix.exs but documented in CLAUDE.md)

**Development/Testing:**
- ExDoc 0.37.3 (~> 0.30) - Documentation generation from code comments
- Sourceror 1.10.0 (~> 1.8) - AST parsing and code generation (dev/test only)
- Igniter 0.6.30 (~> 0.5) - Code generation and modification framework (dev/test only)

**Testing:**
- Mock 0.3.9 (~> 0.3.0) - Mocking library for unit tests (uses meck under the hood)

## Key Dependencies

**Critical:**
- ash 3.5.8 - Core framework; defines resource DSL, actions, and transformations
- spark 2.3.5 - DSL extension framework; used to build the commanded DSL sections
- decimal 2.3.0 - Precise decimal arithmetic (required by Ash)
- ecto 3.12.5 - Database abstraction (transitive from Ash); used for transaction support via `Ecto.Multi`
- reactor 0.15.2 - Async computation framework for Ash (transitive)

**Infrastructure:**
- jason 1.4.4 - JSON encoding/decoding (required by Ash and Spark)
- telemetry 1.3.0 - Metrics and observability (transitive from Ash)
- splode 0.2.9 - Error handling utilities (transitive from Ash)

## Configuration

**Environment:**
- Configured via `config/config.exs` (imported by `config_env()` conditions)
- Environment-specific configs: `config/dev.exs`, `config/test.exs`, `config/prod.exs`

**Build Configuration:**
- `.formatter.exs` - Code formatter configuration; uses Spark.Formatter plugin
- Formatter imports deps from: `:ash`, `:reactor`
- Spark formatter applies structured formatting to DSL sections

**Key Configuration Settings** (from `config/config.exs`):
- Ash framework settings for resource handling (field access, page types, etc.)
- Spark formatter configuration with section ordering for `Ash.Resource` and `Ash.Domain`

## Platform Requirements

**Development:**
- Elixir 1.18.4
- Erlang/OTP 27.3
- macOS/Linux/Windows with Erlang runtime

**Production:**
- Elixir 1.14+ (minimum, project specifies `~> 1.14`)
- Erlang/OTP with standard libraries
- This is a library, not a standalone application; deployment depends on consuming application

## Package Metadata

**Published As:**
- Package name: `ash_commanded`
- Version: 0.2.0
- Repository: `https://github.com/accountex-org/ash_commanded`
- License: MIT
- Maintainers: Accountex

---

Stack analysis: 2026-09-11
