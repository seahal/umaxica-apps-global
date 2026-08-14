# typed: false
# frozen_string_literal: true

module Base
  module App
    # Model Context Protocol endpoint for the Base app surface.
    #
    # Unauthenticated by design: it exposes only liveness, deployment revision, and this endpoint's
    # own realm/surface labels. No database, session, actor, or environment data is reachable
    # through it, and it offers no write tool.
    class McpsController < BareController
      include ::McpEndpoint

      AUTHENTICATION_MODE = :bare

      rate_limit_mcp_endpoint(realm: "base", surface: "app")

      def create
        render_mcp_response
      end

      private

      def mcp_surface_identity
        McpSurfaceIdentity.new(realm: "base", surface: "app")
      end
    end
  end
end
