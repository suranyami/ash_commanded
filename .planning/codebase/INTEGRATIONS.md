# External Integrations

<!-- refreshed: 2026-09-11 -->

**Analysis Date:** 2026-09-11

## APIs & External Services

This is a library extension for Ash Framework, not a standalone application. AshCommanded provides CQRS/Event Sourcing DSL capabilities but does not directly integrate with external APIs. Integration with external services occurs in consuming applications that use this library.

## Data Storage

**Databases:**
- Not directly configured; this is a library, not an application
- Ecto 3.12.5 is a transitive dependency (via Ash Framework)
- Database integration occurs through Ash resources in consuming applications
- Transaction support available via `AshCommanded.Commanded.Transaction` module using `Ecto.Multi` from `lib/commanded/transaction.ex`

**File Storage:**
- Not applicable

**Caching:**
- Not applicable; depends on consuming application

## Authentication & Identity

**Auth Provider:**
- Not applicable; this is a library
- Consuming applications handle authentication via Ash Framework's authentication mechanisms

## Monitoring & Observability

**Error Tracking:**
- Not configured in this library
- Telemetry 1.3.0 (transitive dependency) available for metrics collection in consuming applications
- `AshCommanded.Commanded.Error` module provides standardized error handling via `lib/commanded/error.ex`

**Logs:**
- Standard Elixir Logger used in `lib/commanded/middleware/logging_middleware.ex`
- Logging middleware available for command processing pipeline

## CI/CD & Deployment

**Hosting:**
- Not applicable; this is a published library on Hex.pm

**CI Pipeline:**
- GitHub repository: `https://github.com/accountex-org/ash_commanded`
- No CI configuration detected in this repository
- Tests run locally via `mix test` (see `run_tests.sh` script)

## Environment Configuration

**Required env vars:**
- None; this library is configuration-agnostic
- Consuming applications configure environment variables for their own needs

**Secrets location:**
- Not applicable

## Webhooks & Callbacks

**Incoming:**
- Not applicable

**Outgoing:**
- Event handlers can perform side effects and interact with external systems via `AshCommanded.Commanded.EventHandler` from `lib/commanded/event_handler.ex`
- Projections can trigger arbitrary Ash actions that may call external services
- Event handler example in README shows calling `ECommerce.Notifications.send_welcome_email(event.email)` for external side effects

## Integration Points for Consuming Applications

When using AshCommanded in an application, the following integration patterns are supported:

**Commanded Integration** (`lib/commanded/` directory):
- Automatic command routing via generated router modules
- Event handler integration with Commanded event store
- Projector modules that update read models via Ash actions

**Event-Driven Integrations** (`lib/commanded/event_handler.ex`):
- Custom event handlers can subscribe to domain events
- Actions parameter allows calling any Ash action
- Side effects can be performed when events occur

**Database Transactions** (`lib/commanded/transaction.ex`):
- Commands can execute within database transactions via Ecto
- Supports multiple commands in a single transaction
- Validates repository compatibility

---

Integration audit: 2026-09-11
