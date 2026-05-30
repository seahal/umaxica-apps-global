# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class CookieCryptoConfigTest < ActiveSupport::TestCase
    test "signed cookies use SHA256 instead of SHA1" do
      assert_equal "SHA256", Rails.application.config.action_dispatch.signed_cookie_digest
    end

    test "encrypted cookies use authenticated AES 256 GCM" do
      assert_equal "aes-256-gcm", Rails.application.config.action_dispatch.encrypted_cookie_cipher
      assert Rails.application.config.action_dispatch.use_authenticated_cookie_encryption
    end

    test "secret_credential key base is long enough for derived cookie keys" do
      assert_operator Rails.application.secret_key_base.to_s.bytesize, :>=, 64
    end
  end
end
