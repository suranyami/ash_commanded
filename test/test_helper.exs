# Set up test environment

# Check if Commanded is available
commanded_available? = Code.ensure_loaded?(Commanded.Application)

# Configure ExUnit
exclude_tags =
  if commanded_available? do
    [:skip]
  else
    [:skip, :skip_if_no_commanded]
  end

ExUnit.configure(
  exclude: exclude_tags,
  trace: false,
  seed: 0
)

ExUnit.start()
