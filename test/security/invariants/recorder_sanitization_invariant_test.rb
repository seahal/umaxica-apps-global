# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

module Security
  module Invariants
    class RecorderSanitizationInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      RAW_SECRET_VALUES = [
        "raw-secret-value",
        "123456",
        "raw-token",
        "raw-refresh",
        "raw-access",
        "raw-session",
        "Bearer abc",
        "_session=abc",
        "proof.jwt",
      ].freeze

      test "recorder removes dangerous keys and sanitizes nested sensitive values" do
        payload = {
          password: "raw-secret-value",
          Secret: "case-raw-secret-value",
          otp: "123456",
          token: "raw-token",
          refresh_token: "raw-refresh",
          access_token: "raw-access",
          session_id: "raw-session",
          authorization: "Bearer abc",
          cookie: "_session=abc",
          dpop: "proof.jwt",
          nested: {
            note: "password=raw-secret-value otp=123456 token=abcdefghijklmnopqrstuvwxyzabcdef",
            array: [
              { "Authorization" => "Bearer abc" },
              "refresh_token=abcdefghijklmnopqrstuvwxyzabcdef",
            ],
          },
          ip_address: "203.0.113.10",
          user_agent: "Raw User Agent",
          session_id_digest: "digest-is-allowed",
        }

        sanitized = ChronicleRecorder.sanitize(payload)
        serialized = sanitized.to_json

        RAW_SECRET_VALUES.each do |value|
          assert_not_includes serialized, value
        end
        assert_not sanitized.key?("password")
        assert_not sanitized.key?("Secret")
        assert_not sanitized.key?("authorization")
        assert_not sanitized.key?("cookie")
        assert_not sanitized.key?("dpop")
        assert_not sanitized.key?("ip_address")
        assert_not sanitized.key?("user_agent")
        assert_equal "digest-is-allowed", sanitized.fetch("session_id_digest")
        assert_includes serialized, "[FILTERED]"
      end
    end
  end
end
