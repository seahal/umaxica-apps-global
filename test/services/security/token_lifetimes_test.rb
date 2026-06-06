# frozen_string_literal: true

require "test_helper"

module Security
  class TokenLifetimesTest < ActiveSupport::TestCase
    test "defines application token family lifetimes outside low-level jwt primitives" do
      assert_equal 1.hour, SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL
      assert_equal 7.days, SecurityTokenLifetimes::PREFERENCE_JWT_TTL
      assert_equal 5.minutes, SecurityTokenLifetimes::OIDC_ID_TOKEN_TTL
      assert_equal 5.minutes, SecurityTokenLifetimes::JUMP_RT_TTL
    end

    test "defines old kid verification windows as token ttl plus jwks and cdn leeway" do
      assert_equal 3.hours, SecurityTokenLifetimes.old_kid_verification_window(SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL)
      assert_equal 7.days + 2.hours,
                   SecurityTokenLifetimes.old_kid_verification_window(SecurityTokenLifetimes::PREFERENCE_JWT_TTL)
      assert_equal 2.hours + 5.minutes,
                   SecurityTokenLifetimes.old_kid_verification_window(SecurityTokenLifetimes::OIDC_ID_TOKEN_TTL)
      assert_equal 2.hours + 5.minutes,
                   SecurityTokenLifetimes.old_kid_verification_window(SecurityTokenLifetimes::JUMP_RT_TTL)
    end

    test "keeps existing family constants aligned with the application policy" do
      assert_equal SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL, AuthenticationBase::ACCESS_TOKEN_TTL
      assert_equal SecurityTokenLifetimes::PREFERENCE_JWT_TTL, PreferenceBase::ACCESS_TOKEN_TTL
      assert_equal SecurityTokenLifetimes::PREFERENCE_JWT_TTL, PreferenceToken::ACCESS_TOKEN_TTL
      assert_equal SecurityTokenLifetimes::OIDC_ID_TOKEN_TTL, OidcIdTokenIssuer::TOKEN_TTL
      assert_equal SecurityTokenLifetimes::JUMP_RT_TTL, JumpRtIssuer::DEFAULT_TTL
      assert_equal SecurityTokenLifetimes::JUMP_RT_TTL, JumpRtIssuer::MAX_TTL
      assert_equal SecurityTokenLifetimes::JUMP_RT_TTL, JumpRtReturnVerifier::DEFAULT_MAX_TTL
    end
  end
end
