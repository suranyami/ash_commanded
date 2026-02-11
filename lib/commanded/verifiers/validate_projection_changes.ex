defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionChanges do
  @moduledoc """
  Verifies that projection changes contain valid attribute references.

  This ensures that when using a static map of changes, all keys in the map
  correspond to attributes that exist on the resource.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    projections = Verifier.get_entities(dsl_state, [:commanded, :projections])
    attributes = Verifier.get_entities(dsl_state, [:attributes])

    attribute_names = Enum.map(attributes, & &1.name)

    # Only check projections with map-based changes (skip function-based changes)
    projections_with_invalid_changes =
      projections
      |> Enum.filter(fn projection -> is_map(projection.changes) end)
      |> Enum.map(fn projection ->
        # Find invalid attribute names in the changes map
        invalid_attrs =
          projection.changes
          |> Map.keys()
          |> Enum.filter(fn attr -> attr not in attribute_names end)

        {projection, invalid_attrs}
      end)
      |> Enum.filter(fn {_projection, invalid_attrs} -> length(invalid_attrs) > 0 end)

    case projections_with_invalid_changes do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid, attribute_names)
        {:error, DslError.exception(message: message, path: [:commanded, :projections])}
    end
  end

  defp build_error_message(resource_module, invalid_projections, valid_attributes) do
    projections_list =
      invalid_projections
      |> Enum.map(fn {projection, invalid_attrs} ->
        invalid_attrs_str = Enum.map(invalid_attrs, &inspect/1) |> Enum.join(", ")
        "  - Projection `#{projection.name}` has unknown attributes: #{invalid_attrs_str}"
      end)
      |> Enum.join("\n")

    valid_attributes_list =
      valid_attributes
      |> Enum.map(&"  - #{inspect(&1)}")
      |> Enum.join("\n")

    """
    Some projections in #{inspect(resource_module)} reference attributes that don't exist:

    #{projections_list}

    The following attributes are defined in #{inspect(resource_module)}:

    #{valid_attributes_list}

    Each key in a projection's changes map must correspond to an attribute in the resource.
    Either update the projection to use valid attributes or add the missing attributes to the resource.
    """
  end
end
