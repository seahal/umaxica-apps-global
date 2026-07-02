# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class ChallengesController < ::Auth::App::ApplicationController
          AUTHENTICATION_MODE = :guest

          before_action :ensure_pending_mfa!

          def show
            @mfa_user = pending_mfa_user
            @can_use_totp = @mfa_user&.totp_enabled?
            @can_use_passkey = @mfa_user&.client_passkeys&.exists?(status_id: ClientPasskeyStatus::ACTIVE)
          end

          private

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            redirect_to(
              auth_app_sign_in_path,
              status: :see_other,
            )
          end
        end
      end
    end
  end
end
