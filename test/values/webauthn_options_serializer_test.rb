# frozen_string_literal: true

require "test_helper"

class WebauthnOptionsSerializerTest < ActiveSupport::TestCase
  test "normalizes hash user ids and snake case credential lists" do
    options = {
      challenge: "challenge",
      user: { id: "user-id" },
      allow_credentials: [{ id: "credential-id", type: "public-key" }],
    }

    serialized = Webauthn::OptionsSerializer.as_json(options)

    assert_equal Base64.urlsafe_encode64("user-id", padding: false), serialized.dig("user", "id")
    assert_equal "credential-id", serialized.dig("allow_credentials", 0, "id")
    assert_equal "public-key", serialized.dig("allow_credentials", 0, "type")
  end

  test "normalizes binary strings byte arrays and integer ids" do
    assert_equal Base64.urlsafe_encode64("binary\x00".b, padding: false),
                 Webauthn::OptionsSerializer.normalize_id("binary\x00".b)
    assert_equal Base64.urlsafe_encode64([0, 1, 255].pack("C*"), padding: false),
                 Webauthn::OptionsSerializer.normalize_id([0, 1, 255])
    assert_equal Base64.urlsafe_encode64("123", padding: false),
                 Webauthn::OptionsSerializer.normalize_id(123)

    object = Object.new

    assert_same object, Webauthn::OptionsSerializer.normalize_id(object)
  end
end
