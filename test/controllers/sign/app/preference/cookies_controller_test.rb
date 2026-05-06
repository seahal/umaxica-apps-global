# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class CookiesControllerTest < ActionDispatch::IntegrationTest
        fixtures :users, :user_preferences,
                 :app_preference_colortheme_options, :app_preferences,
                 :app_preference_cookies

        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @user = users(:one)
          host! @host
        end

        test "PATCH update returns updated preference payload and syncs consent" do
          patch sign_app_preference_cookie_path,
                params: {
                  preference_cookie: {
                    consented: true,
                    functional: true,
                    performant: true,
                    targetable: false,
                  },
                },
                headers: as_user_headers(@user, host: @host),
                as: :json

          assert_response :ok
          assert response.parsed_body.dig("preference", "consented")
          assert response.parsed_body.dig("preference", "functional")
          assert_includes response.headers["Set-Cookie"].to_s, "#{::Preference::CookieName.access}="

          @user.user_preference.reload

          assert @user.user_preference.consented
          assert @user.user_preference.functional
          assert @user.user_preference.performant
          assert_not @user.user_preference.targetable
        end
      end
    end
  end
end
