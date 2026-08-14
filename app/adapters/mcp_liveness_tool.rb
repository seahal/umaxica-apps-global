# typed: false
# frozen_string_literal: true

# MCP tool exposing process liveness.
#
# Deliberately narrower than the `/health` endpoints. `adr/internal-health-endpoint-edge-isolation.md`
# treats dependency and topology detail as an internal reconnaissance surface blocked at the edge,
# so this tool reuses `Health::LivenessCheck` only: it reports whether the process finished booting
# and nothing about databases, dependencies, or infrastructure shape.
class McpLivenessTool < MCP::Tool
  tool_name "system_liveness"
  title "Process liveness"
  # MCP tool metadata is protocol payload consumed by MCP clients, not user-facing UI copy, so it
  # is not localized.
  description "Reports whether this application process has finished booting." # rubocop:disable I18n/RailsI18n/DecorateString

  input_schema(properties: {}, required: [])

  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

  class << self
    def call(server_context:)
      identity = server_context.fetch(:surface_identity)
      result = ::Health::LivenessCheck.call(profile: identity.health_profile)

      MCP::Tool::Response.new([{ type: "text", text: { status: result.status.to_s }.to_json }])
    end
  end
end
