# typed: false
# frozen_string_literal: true

require "openssl"

module PromotionalEmailUnsubscribeToken
  VERSION = "v1"
  SECRET_KEY = :PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT

  module_function

  def generate(email_record, scope:)
    OpenSSL::HMAC.hexdigest("SHA256", secret, message(email_record.public_id, scope: scope))
  end

  def valid?(email_record, token, scope:)
    token = token.to_s
    expected = generate(email_record, scope: scope)
    return false unless token.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, token)
  end

  def message(public_id, scope:)
    "#{scope}:#{public_id}:promotional:#{VERSION}"
  end

  def secret
    Rails.app.creds.option(SECRET_KEY).presence ||
      ENV[SECRET_KEY.to_s].presence ||
      raise(KeyError, "Missing key: [:#{SECRET_KEY}]")
  end
end
