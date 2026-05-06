# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class CookiesControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :users, :user_telephone_statuses, :com_preferences, :com_preference_cookies

        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @user = users(:one)
          @user.user_telephones.create!(
            number: "+819012340001",
            user_telephone_status_id: UserTelephoneStatus::VERIFIED,
          )
          host! @host
        end

        test "PATCH update returns updated preference payload and updates com preference cookie" do
          preference = com_preferences(:two)
          token = encode_preference_jwt(
            preferences: { "consented" => false, "functional" => false, "performant" => false, "targetable" => false },
            host: @host,
            public_id: preference.public_id,
            preference_type: "ComPreference",
          )

          with_preference_jwt_keys(host: @host) do
            cookies[::Preference::CookieName.access] = token

            patch sign_com_preference_cookie_path,
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

          assert_response :ok
          assert response.parsed_body.dig("preference", "consented")
          assert response.parsed_body.dig("preference", "functional")
          assert_includes response.headers["Set-Cookie"].to_s, "#{::Preference::CookieName.access}="

          preference.reload

          assert preference.com_preference_cookie.consented
          assert preference.com_preference_cookie.functional
          assert preference.com_preference_cookie.performant
          assert_not preference.com_preference_cookie.targetable
        end
      end
    end
  end
end
