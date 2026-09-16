## AshCommanded usage rules

AshCommanded is a [Spark](https://hexdocs.pm/spark) DSL extension that generates
[Commanded](https://hexdocs.pm/commanded) CQRS/event-sourcing modules from declarations on an
`Ash.Resource` and, separately, an `Ash.Domain`.

### The two extension modules

| Extension | Applied to | Purpose |
| --- | --- | --- |
| `AshCommanded.Resource.Dsl` | `Ash.Resource` | Declares commands, events, projections, event handlers |
| `AshCommanded.Domain.Dsl` | `Ash.Domain` | Imports `AshCommanded.Resource.Dsl` so `commanded do application do ... end end` parses on a domain |

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts,
    extensions: [AshCommanded.Resource.Dsl]

  commanded do
    # ...
  end
end
```

Both extensions use the same DSL block name, `commanded do ... end` — the block names the
integration (Commanded), the way `postgres do ... end` and `graphql do ... end` do in sibling Ash
extensions.

### Sections inside `commanded do ... end`

`AshCommanded.Resource.Dsl` declares one top-level `:commanded` section holding five nested
sections:

- `commands` — one `command :name do ... end` entity per command. `fields([...])` lists the
  struct fields; `identity_field(:id)` names the field used for aggregate routing; `action :name`
  maps the command to a resource action.
- `events` — one `event :name do ... end` entity per event, with its own `fields([...])`.
- `projections` — one `projection :event_name do ... end` entity mapping an event to a resource
  action and a `changes(...)` map or function.
- `event_handlers` — one `handler :name do ... end` entity that runs a side effect (via
  `events([...])` and `action ...`) without necessarily updating the resource.
- `application` — configures the Commanded application (`otp_app`, `event_store`, `pubsub`,
  `registry`, `include_supervisor?`, and related keys). This section is declared by
  `AshCommanded.Resource.Dsl` but is meant to be used from an `Ash.Domain` via
  `AshCommanded.Domain.Dsl`, which imports the resource extension's macros so the block parses
  there too.

A minimal, domain-neutral example (a real fixture, not illustrative pseudo-code — see
`test/support/parity/parity_widget.ex`):

```elixir
defmodule MyApp.Widget do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshCommanded.Resource.Dsl]

  commanded do
    commands do
      command :create_widget do
        fields([:id, :label])
        identity_field(:id)
        action :create
        event :widget_created
      end
    end

    events do
      event :widget_created do
        fields([:id, :label])
      end
    end

    projections do
      projection :widget_created do
        action :create
        changes(%{})
      end
    end

    event_handlers do
      handler :notifier do
        events([:widget_created])
        action :create
      end
    end
  end

  actions do
    defaults [:read, create: [:id, :label]]
  end

  attributes do
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      writable? true
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :label, :string, public?: true
  end
end
```

### What gets generated, and under what names

Declaring the block above generates, under the declaring resource's own module prefix:

- `MyApp.Widget.Commands.CreateWidget` — a struct with typespecs, one field per `fields([...])`
  entry.
- `MyApp.Widget.Events.WidgetCreated` — likewise, a struct with typespecs.
- A projection module implementing the event-to-action mapping declared in `projections`.
- A projector module (a real Commanded event handler) that applies the projection when the event
  is dispatched.
- An event handler module for each `event_handlers` entity.
- An aggregate module with `execute/2`/`apply/2` clauses derived from the declared
  command-to-event mapping.

Override a generated module's name explicitly inside the relevant entity block rather than
relying on the default, when the default would collide with something else in the consuming
application.

### Introspection: use the `.Info` modules, never DSL state directly

- `AshCommanded.Resource.Info` is the single lookup point for everything declared inside a
  resource's `commanded do ... end` block. For example,
  `AshCommanded.Resource.Info.commanded_commands(MyApp.Widget)` returns the resource's declared
  commands. It is generated entirely by `Spark.InfoGenerator` — there are no hand-written getters
  to fall out of sync with the DSL's actual shape.
- `AshCommanded.Domain.Info` is the equivalent lookup point for a domain. It currently exposes
  zero accessors, because `AshCommanded.Domain.Dsl` declares zero sections of its own today (it
  only imports the resource extension so the block parses) — this is documented, current
  behaviour, not a bug to route around.
- Never read `Spark.Dsl.Extension.get_entities/2` or similar directly from your own code against
  either extension. Go through the `.Info` module.

### Rendering what was generated

`mix ash_commanded.dump <ResourceOrDomainModule>` prints the formatted Elixir source AshCommanded
generated for that module, recovered from the AST exactly as the transformer wrote it (before
`Module.create/3` ran) — this is the honest way to see what a declaration actually produces,
rather than reading the generator and inferring it.

```sh
mix ash_commanded.dump MyApp.Widget
mix ash_commanded.dump MyApp.Widget --only MyApp.Widget.Commands.CreateWidget
mix ash_commanded.dump MyApp.Widget --beam
```

`--only` narrows the output to one generated module. `--beam` shows the ground-truth post-compile
view from the BEAM `debug_info` chunk instead — the same declaration's `use X` lines have already
expanded into the functions they injected in that view, which differs from the default
pre-`Module.create/3` view wherever a macro does real work.

### A capability that does not work yet — say so, don't paper over it

**Domain-level application and router generation does not fire for any domain today.** Both
transformers are registered but each tests a persisted `:module` value that only the resource
extension's compilation ever sets, so a domain declaring `commanded do application do ... end
end` compiles without error but never produces the application or router module the block
appears to configure. This is a known, tracked defect (not a documentation gap) — see
`.planning/PROJECT.md`'s Falsified section. It is owned by this project's Phase 3 (Application and
Routers). Do not write code that depends on domain-level application or router generation until
that phase lands.

### Searching library documentation

```sh
mix usage_rules.search_docs "search term" -p ash -p spark -p commanded
```
