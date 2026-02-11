defmodule AshCommanded.Commanded.ContextBuilderTest do
  use ExUnit.Case, async: false

  # Simple context building module for testing
  defmodule ContextBuilder do
    @doc """
    Builds a context map based on configuration
    """
    def build_context(aggregate, command, opts \\ []) do
      # Default configuration
      include_aggregate? = Keyword.get(opts, :include_aggregate?, true)
      include_command? = Keyword.get(opts, :include_command?, true)
      include_metadata? = Keyword.get(opts, :include_metadata?, true)
      context_prefix = Keyword.get(opts, :context_prefix, nil)
      static_context = Keyword.get(opts, :static_context, %{})

      # Start with empty context
      context = %{}

      # Add aggregate if configured
      context =
        if include_aggregate? do
          key = if context_prefix, do: :"#{context_prefix}.aggregate", else: :aggregate
          Map.put(context, key, aggregate)
        else
          context
        end

      # Add command if configured
      context =
        if include_command? do
          key = if context_prefix, do: :"#{context_prefix}.command", else: :command
          Map.put(context, key, command)
        else
          context
        end

      # Add metadata if present and configured
      context =
        if include_metadata? && Map.has_key?(command, :metadata) do
          metadata = Map.get(command, :metadata, %{})
          base_key = if context_prefix, do: :"#{context_prefix}.metadata", else: :metadata

          # Add as a map under metadata key 
          Map.put(context, base_key, metadata)
        else
          context
        end

      # Add static context if configured
      context =
        if is_map(static_context) && map_size(static_context) > 0 do
          Map.merge(context, static_context)
        else
          context
        end

      context
    end
  end

  describe "context building" do
    test "includes aggregate, command and metadata by default" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context with default options
      context = ContextBuilder.build_context(aggregate, command)

      # Verify context has expected keys
      assert Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      assert Map.has_key?(context, :metadata)

      # Verify context has expected values
      assert context.aggregate == aggregate
      assert context.command == command
      assert context.metadata == %{user_id: "admin"}
    end

    test "can exclude specific context items" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context excluding aggregate
      context = ContextBuilder.build_context(aggregate, command, include_aggregate?: false)

      # Verify aggregate is not in the context, but other items are
      refute Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      assert Map.has_key?(context, :metadata)
    end

    test "supports context key prefixing" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context with prefix
      context = ContextBuilder.build_context(aggregate, command, context_prefix: :cmd)

      # Verify context has prefixed keys
      assert Map.has_key?(context, :"cmd.aggregate")
      assert Map.has_key?(context, :"cmd.command")
      assert Map.has_key?(context, :"cmd.metadata")

      # Verify context has expected values
      assert Map.get(context, :"cmd.aggregate") == aggregate
      assert Map.get(context, :"cmd.command") == command
      assert Map.get(context, :"cmd.metadata") == %{user_id: "admin"}
    end

    test "includes static context" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com"}

      # Static context to include
      static_context = %{
        app_version: "1.0.0",
        environment: :test
      }

      # Build context with static context
      context = ContextBuilder.build_context(aggregate, command, static_context: static_context)

      # Verify context includes static context values
      assert context.aggregate == aggregate
      assert context.command == command
      assert context.app_version == "1.0.0"
      assert context.environment == :test
    end

    test "handles missing metadata gracefully" do
      # Create test aggregate and command without metadata
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com"}

      # Build context
      context = ContextBuilder.build_context(aggregate, command)

      # Verify context does not have metadata key
      assert Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      refute Map.has_key?(context, :metadata)
    end
  end
end
