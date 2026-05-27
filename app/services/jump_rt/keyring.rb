# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"

module JumpRt
  module Keyring
    module_function

    def active_kid(namespace)
      ENV["JWT_#{JumpRt::Surface.normalize_namespace(namespace)}_ACTIVE_KID"].presence
    end

    def private_key(namespace)
      key = Rails.app.creds.option("JWT_#{JumpRt::Surface.normalize_namespace(namespace)}_PRIVATE_KEY")
      decode_private_key(key)
    end

    def decode_private_key(value)
      return nil if value.blank?

      raw = value.to_s
      return OpenSSL::PKey.read(raw) if raw.include?("BEGIN")

      OpenSSL::PKey::EC.new(Base64.decode64(raw))
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      nil
    end
  end
end
