# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Mfa
        class ResetsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          def show = (authorize!(current_client, to: :show?); render "base/app/identity/mfa/resets/show")

          def create
            authorize!(current_client, to: :update?)
            current_client.update!(
              mfa_level_id: ClientMfaLevel::NOTHING,
              mfa_level_enabled: false,
            )
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: :mfa_reset,
              affected_surface: "app",
              request: request,
            )
            redirect_to(
              base_app_identity_mfa_reset_path(ri: params[:ri]),
              status: :see_other,
            )
          end
        end
      end
    end
  end
end
