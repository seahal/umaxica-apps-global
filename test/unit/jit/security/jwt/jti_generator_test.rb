# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_jti_generator"

module Jit
  module Security
    module Jwt
      class JtiGeneratorTest < ActiveSupport::TestCase
        test "generate returns a base64url string at the expected length" do
          jti = JitSecurityJwtJtiGenerator.generate

          assert_match(JitSecurityJwtJtiGenerator::BASE64URL_REGEX, jti)
          assert_equal JitSecurityJwtJtiGenerator.encoded_length(JitSecurityJwtJtiGenerator::DEFAULT_BYTES),
                       jti.length
          assert_no_match(/\A[0-9a-f-]{36}\z/i, jti)
        end

        test "generate accepts a custom byte count" do
          jti = JitSecurityJwtJtiGenerator.generate(JitSecurityJwtJtiGenerator::MINIMUM_BYTES)

          assert_equal JitSecurityJwtJtiGenerator.encoded_length(JitSecurityJwtJtiGenerator::MINIMUM_BYTES),
                       jti.length
        end

        test "generate omits base64url padding for byte counts that would otherwise require it" do
          jti = JitSecurityJwtJtiGenerator.generate(17)

          assert_match(JitSecurityJwtJtiGenerator::BASE64URL_REGEX, jti)
          assert_equal JitSecurityJwtJtiGenerator.encoded_length(17), jti.length
          assert_not_includes jti, "="
        end

        test "generate returns a different value each call" do
          first = JitSecurityJwtJtiGenerator.generate
          second = JitSecurityJwtJtiGenerator.generate

          assert_not_equal first, second
        end
      end
    end
  end
end
