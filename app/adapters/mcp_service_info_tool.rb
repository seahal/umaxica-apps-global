# typed: false
# frozen_string_literal: true

# MCP tool identifying which realm and surface this endpoint serves.
#
# The identity comes from `server_context`, which the concrete controller declares, rather than from
# `request.host`. A tool that parsed the host itself would be one host-header bug away from
# answering for the wrong surface.
class McpServiceInfoTool < MCP::Tool
  tool_name "service_info"
  title "Service identity"
  # MCP tool metadata is protocol payload consumed by MCP clients, not user-facing UI copy, so it
  # is not localized.
  description "Returns the realm and surface this MCP endpoint serves." # rubocop:disable I18n/RailsI18n/DecorateString

  input_schema(properties: {}, required: [])

  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

  class << self
    def call(server_context:)
      identity = server_context.fetch(:surface_identity)

      MCP::Tool::Response.new([{ type: "text", text: identity.as_public_json.to_json }])
    end
  end
end
