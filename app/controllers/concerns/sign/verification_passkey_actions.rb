# typed: false
# frozen_string_literal: true

module Sign
  module VerificationPasskeyActions
    extend ActiveSupport::Concern

    def new
      return unless require_step_up_session!
      return if redirect_if_recent_verification_for_get!
      return unless require_method_available!(:passkey)

      prepare_passkey_challenge!
    end

    def create
      return unless require_step_up_session!
      return if redirect_if_recent_verification_for_post!
      return unless require_method_available!(:passkey)

      if verify_passkey!
        consume_step_up_session!(method: :passkey)
      else
        record_failed_step_up_attempt!(:passkey)
        prepare_passkey_challenge!
        render :new, status: :unprocessable_content
      end
    end
  end
end
