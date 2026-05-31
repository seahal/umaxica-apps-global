# frozen_string_literal: true

require "test_helper"

module Security
  class TokenLifetimesTest < ActiveSupport::TestCase
    test "defines application token family lifetimes outside low-level jwt primitives" do
      assert_equal 1.hour, TokenLifetimes::AUTH_ACCESS_JWT_TTL
      assert_equal 7.days, TokenLifetimes::PREFERENCE_JWT_TTL
      assert_equal 5.minutes, TokenLifetimes::OIDC_ID_TOKEN_TTL
      assert_equal 5.minutes, TokenLifetimes::JUMP_RT_TTL
    end

    test "defines old kid verification windows as token ttl plus jwks and cdn leeway" do
      assert_equal 3.hours, TokenLifetimes.old_kid_verification_window(TokenLifetimes::AUTH_ACCESS_JWT_TTL)
      assert_equal 7.days + 2.hours,
                   TokenLifetimes.old_kid_verification_window(TokenLifetimes::PREFERENCE_JWT_TTL)
      assert_equal 2.hours + 5.minutes,
                   TokenLifetimes.old_kid_verification_window(TokenLifetimes::OIDC_ID_TOKEN_TTL)
      assert_equal 2.hours + 5.minutes,
                   TokenLifetimes.old_kid_verification_window(TokenLifetimes::JUMP_RT_TTL)
    end

    test "keeps existing family constants aligned with the application policy" do
      assert_equal TokenLifetimes::AUTH_ACCESS_JWT_TTL, Authentication::Base::ACCESS_TOKEN_TTL
      assert_equal TokenLifetimes::PREFERENCE_JWT_TTL, Preference::Base::ACCESS_TOKEN_TTL
      assert_equal TokenLifetimes::PREFERENCE_JWT_TTL, Preference::Token::ACCESS_TOKEN_TTL
      assert_equal TokenLifetimes::OIDC_ID_TOKEN_TTL, Oidc::IdTokenIssuer::TOKEN_TTL
      assert_equal TokenLifetimes::JUMP_RT_TTL, JumpRt::Issuer::DEFAULT_TTL
      assert_equal TokenLifetimes::JUMP_RT_TTL, JumpRt::Issuer::MAX_TTL
      assert_equal TokenLifetimes::JUMP_RT_TTL, JumpRt::ReturnVerifier::DEFAULT_MAX_TTL
    end
  end
end
