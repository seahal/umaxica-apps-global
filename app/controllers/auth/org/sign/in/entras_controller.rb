# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # EntrasController renders the Microsoft Entra ID sign-in landing page.
        #
        # Ceremony flow:
        # 1. GET  /sign/in/entra/new          — this controller; operator sees "Sign in with Microsoft"
        # 2. POST /sign/in/entra/authorization — Entra::AuthorizationsController#create
        # 3. GET  /sign/in/entra/callback      — Entra::CallbacksController#show
        #
        # Shared ceremony invariants live in OrgEntraCeremony.
        # See adr/org-entra-id-sign-in-boundary.md.
        class EntrasController < ::Auth::Org::ApplicationController
          AUTHENTICATION_MODE = :guest

          # GET /sign/in/entra/new
          # Shows the Entra sign-in landing page with a "Sign in with Microsoft" button.
          # Requires ?connection=PUBLIC_ID to identify which Entra connection to use.
          def new
            connection_public_id = params[:connection].to_s.strip
            @connection = OrganizationEntraConnection.find_by(
              public_id: connection_public_id,
              status_id: OrganizationEntraConnectionState::ACTIVE,
            ) if connection_public_id.present?
          end
        end
      end
    end
  end
end
