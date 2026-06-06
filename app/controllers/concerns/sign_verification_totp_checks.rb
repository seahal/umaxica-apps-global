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

    result = active_totp_credentials.any? { |totp| ROTP::TOTP.new(totp.private_key).verify(code) }
    @verification_errors = ["確認コードが正しくありません"] unless result
    result
  end

  def active_totp_credentials
    raise NotImplementedError, "#{self.class} must define #active_totp_credentials"
  end
end
