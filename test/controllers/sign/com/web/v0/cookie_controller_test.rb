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

  test "PATCH update without access jwt raises instead of silently dropping persistence" do
    cookies.delete(Preference::CookieName.access)

    assert_raises(RuntimeError, match: /missing_preference_access_token/) do
      patch sign_com_web_v0_cookie_path, params: { consented: true }, as: :json
    end
  end
end
