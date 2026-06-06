# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class ChallengesController < ::Sign::Com::ApplicationController
        AUTHENTICATION_MODE = :guest

        before_action :ensure_pending_mfa!

        def show
          @mfa_user = pending_mfa_user
          @can_use_passkey = @mfa_user&.visitor_passkeys&.exists?(status_id: VisitorPasskeyStatus::ACTIVE)
        end

        private

        def ensure_pending_mfa!
          return unless !pending_mfa_valid? || pending_mfa_user.nil?

          clear_pending_mfa!
          redirect_to(
            sign_com_sign_in_entrance_path(ri: params[:ri]),
            alert: I18n.t("sign.app.in.mfa.session_expired"),
            status: :see_other,
          )
        end
      end
    end
  end
end
