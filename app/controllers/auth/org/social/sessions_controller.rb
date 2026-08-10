# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Social
      # Starts the OmniAuth-based Microsoft Entra ID sign-in ceremony.
      #
      # GET  /social/entra/session/new
      # POST /social/entra/session
      #
      # Both actions render a POST form (CSRF-protected via
      # omniauth-rails_csrf_protection) targeting /social/entra, carrying the
      # operator's chosen OrganizationEntraConnection#public_id.
      #
      # Unlike the app surface's Google and Apple buttons, which post straight
      # to the OmniAuth request phase, Entra needs one cushion step: the
      # strategy resolves the tenant, client id, and credential key per request
      # from the connection (lib/omniauth/strategies/umaxica_entra.rb), so
      # without a connection there is no Entra tenant to send the operator to.
      # #create hands off with a 307 once the connection is known, mirroring
      # Auth::App::Social::AuthenticationsController#handoff_social_ceremony!.
      #
      # See adr/org-entra-id-sign-in-boundary.md and
      # adr/org-entra-omniauth-strategy-migration.md.
      class SessionsController < ::Auth::Org::ApplicationController
        include ExternalAuthenticationEndpoint

        AUTHENTICATION_MODE = :guest

        PT_SESSION_KEY = :auth_org_entra_omniauth_pt

        # The OmniAuth request phase this action hands off to; a fixed path
        # owned by the middleware rather than a named route.
        OMNIAUTH_REQUEST_PATH = "/social/entra"

        rate_limit(
          to: 20,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_org_sign_in_entra",
          name: "ceremony_start_ip_burst",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(rule_name: "auth_org_sign_in_entra_ceremony_start_ip_burst", retry_after: 60)
          },
        )

        def new
          stash_pt!
          @provider_available = entra_start_available?
          @connection = active_connection(requested_connection_public_id) if @provider_available
        end

        # POST /social/entra/session
        #
        # Reached by the sign-in page button (no connection yet, so the cushion
        # page is rendered) and by the cushion page's own form (connection
        # supplied, so the ceremony starts).
        def create
          stash_pt!

          unless entra_start_available?
            @provider_available = false
            return render(:new, status: :service_unavailable)
          end

          @provider_available = true
          @connection = active_connection(requested_connection_public_id)

          if @connection.present?
            # 307 preserves the method, body, and CSRF token, handing this same
            # POST to the OmniAuth request phase, which requires a
            # token-protected POST of its own
            # (OmniAuth.config.allowed_request_methods = [:post]).
            return redirect_to(OMNIAUTH_REQUEST_PATH, status: :temporary_redirect)
          end

          # Blank input is the button's first arrival, not a failed lookup.
          @connection_error = requested_connection_public_id.present?
          render(:new, status: @connection_error ? :unprocessable_content : :ok)
        end

        private

        def stash_pt!
          session[PT_SESSION_KEY] = signed_pt_param if signed_pt_param.present?
        end

        # Accepts both the link contract (?connection=) used by administrator-
        # distributed URLs and the cushion form's field name.
        def requested_connection_public_id
          @requested_connection_public_id ||=
            params[:connection_public_id].presence.to_s.strip.presence ||
            params[:connection].to_s.strip
        end

        def active_connection(public_id)
          return if public_id.blank?

          OrganizationEntraConnection.find_by(
            public_id: public_id,
            status_id: OrganizationEntraConnectionState::ACTIVE,
          )
        end

        # Mirrors the strategy's own request-phase gate
        # (UmaxicaEntra#entra_start_available?) so a :social_ceremony_org_entra kill
        # switch stops the ceremony at the entry point rather than only after
        # the operator has pressed the button.
        def entra_start_available?
          external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
            external_authentication_start_available?(provider: "entra", operation: "login", context: {})
        end
      end
    end
  end
end
