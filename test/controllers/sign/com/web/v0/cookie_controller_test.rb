# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

class Sign::Com::Web::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = Jit::IdHostEnv.corporate_url || "id.com.localhost"
    host! @host
  end

  test "PATCH update without access jwt writes consent buffer without persisting preference" do
    cookies.delete(Preference::CookieName.access)

    assert_no_difference -> { VisitorPreference.count } do
      patch sign_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end

    assert_response :ok
    assert response.parsed_body["consented"]
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=1"
    assert_not_includes set_cookie, "#{Preference::CookieName.access}="
  end
end
