# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Auth::Com::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = JitIdHostEnv.corporate_url || "id.com.localhost"
    host! @host
  end

  test "PATCH update without access jwt writes consent buffer without credential cookies" do
    cookies.delete(PreferenceCookieName.access)

    assert_no_difference -> { VisitorPreference.count } do
      patch auth_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s
    consent_cookie = response_set_cookie_lines.find { |line| line.start_with?("preference_consented=") }.to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_includes consent_cookie.downcase, "samesite=strict"
    assert_not_includes consent_cookie.downcase, "httponly"
    assert_not_includes set_cookie, "#{PreferenceCookieName.access}="
    assert_not_includes set_cookie, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
  end
end
