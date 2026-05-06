# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :users, :user_telephone_statuses, :com_preferences

        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @user = users(:one)
          @user.user_telephones.create!(
            number: "+819012340004",
            user_telephone_status_id: UserTelephoneStatus::VERIFIED,
          )
          host! @host
        end

        test "DELETE destroy resets com preference defaults" do
          preference = com_preferences(:two)
          cookie = com_preference_cookies(:two)
          cookie.update!(
            consented: true,
            functional: true,
            performant: true,
            targetable: true,
          )
          region = ComPreferenceRegion.create!(preference: preference, option_id: ComPreferenceRegionOption::US)
          timezone = ComPreferenceTimezone.create!(preference: preference, option_id: ComPreferenceTimezoneOption::ETC_UTC)
          colortheme = ComPreferenceColortheme.create!(
            preference: preference,
            option_id: ComPreferenceColorthemeOption::DARK,
          )
          token = encode_preference_jwt(
            preferences: { "ri" => "us", "tz" => "Etc/UTC", "ct" => "dr", "consented" => true },
            host: @host,
            public_id: preference.public_id,
            preference_type: "ComPreference",
          )

          with_preference_jwt_keys(host: @host) do
            cookies[::Preference::CookieName.access] = token

            delete sign_com_preference_reset_path,
                   params: { confirm_reset: "1" },
                   headers: as_user_headers(@user, host: @host)
          end

          assert_redirected_to edit_sign_com_preference_reset_path

          [preference, cookie, region, timezone, colortheme].each(&:reload)

          assert_not cookie.consented
          assert_not cookie.functional
          assert_not cookie.performant
          assert_not cookie.targetable
          assert_equal ComPreferenceRegionOption::JP, region.option_id
          assert_equal ComPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
          assert_equal ComPreferenceColorthemeOption::SYSTEM, colortheme.option_id
        end
      end
    end
  end
end
