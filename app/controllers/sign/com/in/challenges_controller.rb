# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class ChallengesController < GuestController
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
            new_sign_com_in_path(ri: params[:ri]),
            alert: I18n.t("sign.app.in.mfa.session_expired"),
            status: :see_other,
          )
        end
      end
    end
  end
end
