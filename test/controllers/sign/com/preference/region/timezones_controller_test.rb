# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      module Region
        class TimezonesControllerTest < ActionDispatch::IntegrationTest
          include PreferenceJwtHelper

          fixtures :users, :user_telephone_statuses, :com_preferences

          setup do
            @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
            @user = users(:one)
            @user.user_telephones.create!(
              number: "+819012340003",
              user_telephone_status_id: UserTelephoneStatus::VERIFIED,
            )
            host! @host
          end

          test "PATCH update syncs timezone to com preference" do
            preference = com_preferences(:one)
            ComPreferenceTimezone.create!(preference: preference, option_id: ComPreferenceTimezoneOption::ASIA_TOKYO)
            token = encode_preference_jwt(
              preferences: { "tz" => "Asia/Tokyo" },
              host: @host,
              public_id: preference.public_id,
              preference_type: "ComPreference",
            )

            with_preference_jwt_keys(host: @host) do
              cookies[::Preference::CookieName.access] = token

              patch sign_com_preference_region_timezone_path,
                    params: { preference_timezone: { option_id: ComPreferenceTimezoneOption::ETC_UTC } },
                    headers: as_user_headers(@user, host: @host)
            end

            assert_redirected_to edit_sign_com_preference_region_timezone_url

            preference.reload

            assert_equal ComPreferenceTimezoneOption::ETC_UTC, preference.com_preference_timezone.option_id
          end
        end
      end
    end
  end
end
