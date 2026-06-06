# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module In
      class ChallengesController < ::Sign::Org::ApplicationController
        AUTHENTICATION_MODE = :guest

        before_action :ensure_pending_mfa!

        def show
          @mfa_staff = pending_mfa_user
          @can_use_passkey = @mfa_staff&.staff_passkeys&.exists?(status_id: OperatorPasskeyStatus::ACTIVE)
        end

        private

        def ensure_pending_mfa!
          return unless !pending_mfa_valid? || pending_mfa_user.nil?

          clear_pending_mfa!
          redirect_to(
            sign_org_sign_in_entrance_path,
            alert: I18n.t("sign.org.in.mfa.session_expired"),
            status: :see_other,
          )
        end
      end
    end
  end
end
