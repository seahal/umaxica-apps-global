# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module Com
    module Preference
      module Region
        class TimezonesControllerTest < ActionDispatch::IntegrationTest
          include PreferenceJwtHelper

          fixtures :com_preferences

          setup do
            @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
            @visitor = create_verified_visitor_with_email(
              email_address: "preference-timezone-#{SecureRandom.hex(4)}@example.com",
            )
            @visitor.visitor_telephones.create!(
              number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
              visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
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
                    headers: as_visitor_headers(@visitor, host: @host)
            end

            assert_redirected_to edit_sign_com_preference_region_timezone_url(ri: "jp")

            preference.reload

            assert_equal ComPreferenceTimezoneOption::ETC_UTC, preference.com_preference_timezone.option_id
          end
        end
      end
    end
  end
end
