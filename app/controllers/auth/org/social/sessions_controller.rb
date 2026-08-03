# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Social
      # Starts the OmniAuth-based Microsoft Entra ID sign-in ceremony.
      #
      # GET /social/entra/session/new
      # Renders a POST form (CSRF-protected via omniauth-rails_csrf_protection)
      # targeting /social/entra, carrying the operator's chosen
      # OrganizationEntraConnection#public_id.
      #
      # See adr/org-entra-id-sign-in-boundary.md and
      # lib/omniauth/strategies/umaxica_entra.rb.
      class SessionsController < ::Auth::Org::ApplicationController
        AUTHENTICATION_MODE = :guest

        PT_SESSION_KEY = :auth_org_entra_omniauth_pt

        def new
          connection_public_id = params[:connection].to_s.strip
          @connection = OrganizationEntraConnection.find_by(
            public_id: connection_public_id,
            status_id: OrganizationEntraConnectionState::ACTIVE,
          ) if connection_public_id.present?

          session[PT_SESSION_KEY] = signed_pt_param if signed_pt_param.present?
        end
      end
    end
  end
end
