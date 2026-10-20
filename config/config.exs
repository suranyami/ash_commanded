import Config

# Ash 3.36 refuses to compile without this setting: its
# `Ash.Resource.Transformers.RequireStringLengthCountConfig` runs during
# `__before_compile__` for every resource, so the absence blocks all DSL-using
# modules at compile time. The two options are `:codepoints` and `:mixed`.
# `:codepoints` is Ash's recommended value: it counts string length the same way
# SQL data layers do, so a `max_length` constraint bounds the stored size
# consistently across ETS and Postgres-backed resources. `:mixed` counts some
# non-BMP characters differently and would make the bound storage-dependent.
config :ash,
  default_string_length_count: :codepoints,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [section_order: [:resources, :policies, :authorization, :domain, :execution]]
  ]

import_config "#{config_env()}.exs"
