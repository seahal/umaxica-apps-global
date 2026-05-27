# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module App
    module Preference
      class CookiesControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :clients, :client_preferences,
                 :app_preference_theme_options, :app_preferences,
                 :app_preference_cookies

        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @user = clients(:one)
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
          assert_includes(
            response.headers["Set-Cookie"].to_s,
            "#{::Preference::CookieName.access(surface: :app)}=",
          )

          @user.user_preference.reload

          assert @user.user_preference.consented
          assert @user.user_preference.functional
          assert @user.user_preference.performant
          assert_not @user.user_preference.targetable
        end

        test "PATCH update persists even when preference access token cannot be issued" do
          with_preference_jwt_keys(host: @host) do
            ::Preference::Token.stub(:encode, nil) do
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
            end
          end

          assert_response :ok

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
