# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module Com
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :com_preferences

        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @visitor = create_verified_visitor_with_email(
            email_address: "preference-reset-#{SecureRandom.hex(4)}@example.com",
          )
          @visitor.visitor_telephones.create!(
            number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
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
          theme = ComPreferenceTheme.create!(
            preference: preference,
            option_id: ComPreferenceThemeOption::DARK,
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
                   headers: as_visitor_headers(@visitor, host: @host)
          end

          assert_response :see_other
          assert_redirected_to sign_com_preference_path

          [preference, cookie, region, timezone, theme].each(&:reload)

          assert_not cookie.consented
          assert_not cookie.functional
          assert_not cookie.performant
          assert_not cookie.targetable
          assert_equal ComPreferenceRegionOption::JP, region.option_id
          assert_equal ComPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
          assert_equal ComPreferenceThemeOption::SYSTEM, theme.option_id
        end

        test "DELETE destroy redirects anonymous reset to com preference index" do
          delete sign_com_preference_reset_path,
                 params: { confirm_reset: "1" }

          assert_response :see_other
          assert_redirected_to sign_com_preference_path
        end
      end
    end
  end
end
