# typed: false
# frozen_string_literal: true

module SignVerificationTotpChecks
  extend ActiveSupport::Concern

  private

  def verify_totp!
    code = verification_params[:code].to_s
    unless code.match?(/\A\d{6}\z/)
      @verification_errors = ["確認コードが不正です"]
      return false
    end

    result = TotpWindowConsumer.call(credentials: active_totp_credentials, token: code)
    @verification_errors = ["確認コードが正しくありません"] unless result.accepted?
    result.accepted?
  end

  def active_totp_credentials
    raise NotImplementedError, "#{self.class} must define #active_totp_credentials"
  end
end
