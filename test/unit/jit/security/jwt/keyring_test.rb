# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_keyring"

module Jit
  module Security
    module Jwt
      class KeyringTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        def with_active_kid_env(value)
          previous_value = ENV["AUTH_JWT_ACTIVE_KID"]
          value.nil? ? ENV.delete("AUTH_JWT_ACTIVE_KID") : ENV["AUTH_JWT_ACTIVE_KID"] = value
          yield
        ensure
          previous_value.nil? ? ENV.delete("AUTH_JWT_ACTIVE_KID") : ENV["AUTH_JWT_ACTIVE_KID"] = previous_value
        end

        test "active_kid returns boot-time registry value" do
          assert_equal JitSecurityJwtRegistry.auth.current_kid, JitSecurityJwtKeyring.active_kid
        end

        test "active_kid ignores request-time ENV changes" do
          boot_kid = JitSecurityJwtKeyring.active_kid

          with_active_kid_env("custom-kid") do
            assert_equal boot_kid, JitSecurityJwtKeyring.active_kid
          end
        end

        test "parse_keyset returns empty hash for blank input" do
          assert_equal({}, JitSecurityJwtKeyring.parse_keyset(nil))
          assert_equal({}, JitSecurityJwtKeyring.parse_keyset(""))
          assert_equal({}, JitSecurityJwtKeyring.parse_keyset("   "))
        end

        test "parse_keyset parses valid JSON hash" do
          raw = '{"kid1": "key1", "kid2": "key2"}'
          result = JitSecurityJwtKeyring.parse_keyset(raw)

          assert_equal "key1", result["kid1"]
          assert_equal "key2", result["kid2"]
        end

        test "parse_keyset returns empty hash for invalid JSON" do
          assert_equal({}, JitSecurityJwtKeyring.parse_keyset("not valid json"))
        end

        test "parse_keyset returns empty hash for non-hash JSON" do
          assert_equal({}, JitSecurityJwtKeyring.parse_keyset('["key1", "key2"]'))
        end

        test "decode_key returns nil for blank input" do
          assert_nil JitSecurityJwtKeyring.decode_key(nil)
          assert_nil JitSecurityJwtKeyring.decode_key("")
        end

        test "parse_header returns empty hash for invalid token" do
          assert_equal({}, JitSecurityJwtKeyring.parse_header("invalid.token"))
        end

        test "parse_header returns header for valid token" do
          # Create a minimal valid JWT header
          header = { "alg" => "ES384", "typ" => "JWT" }
          encoded = Base64.urlsafe_encode64(header.to_json, padding: false)
          token = "#{encoded}.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature"

          result = JitSecurityJwtKeyring.parse_header(token)

          assert_equal "ES384", result["alg"]
          assert_equal "JWT", result["typ"]
        end

        test "parse_header returns empty hash on decode error" do
          assert_equal({}, JitSecurityJwtKeyring.parse_header("not.a.valid.jwt"))
        end
      end
    end
  end
end
