# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      class EntrasController < ::Auth::Org::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :authorize_entra_settings!
        before_action :set_entra_identity, only: %i(show edit)
        before_action :set_entra_connections, only: %i(show edit)

        def show
        end

        def edit
        end

        def create
          connection = OrganizationEntraConnection.find_by!(
            public_id: entra_params.fetch(:connection_public_id),
            status_id: OrganizationEntraConnectionState::ACTIVE,
          )

          redirect_to(
            new_auth_org_social_entra_session_path(connection: connection.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          set_entra_identity
          set_entra_connections
          render :edit, status: :unprocessable_content
        end

        private

        def authorize_entra_settings!
          authorize!(current_operator, to: :show?)
        end

        def set_entra_identity
          @entra_identity = OperatorEntraIdentity.find_by(
            operator_id: current_operator.id,
            status_id: OperatorEntraIdentityState::ACTIVE,
          )
        end

        def set_entra_connections
          @entra_connections = OrganizationEntraConnection.where(
            status_id: OrganizationEntraConnectionState::ACTIVE,
          ).order(created_at: :asc)
        end

        def entra_params
          params.expect(entra: [:connection_public_id])
        end
      end
    end
  end
end
