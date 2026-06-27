# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class VerificationsController < Verification::BaseController
      include SignVerificationEntry

      AUTHENTICATION_MODE = :private

      private

      def verification_success_notice_key
        "sign.app.verification.success.complete"
      end

      def verification_invalid_request_redirect_path(ri:)
        sign_com_settings_path(ri: ri)
      end
    end
  end
end
