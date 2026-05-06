# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class RegionsControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :com_preferences

        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @customer = create_verified_customer_with_email(
            email_address: "preference-#{SecureRandom.hex(4)}@example.com",
          )
          @customer.customer_telephones.create!(
            number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
          )
          host! @host
        end

        test "PATCH update syncs region to com preference and customer preference" do
          preference = com_preferences(:one)
          ComPreferenceRegion.create!(preference: preference, option_id: ComPreferenceRegionOption::JP)
          @customer.create_customer_preference!(
            region: "jp",
            language: "ja",
            timezone: "Asia/Tokyo",
            theme: "sy",
          )
          token = encode_preference_jwt(
            preferences: { "ri" => "jp" },
            host: @host,
            public_id: preference.public_id,
            preference_type: "ComPreference",
          )

          with_preference_jwt_keys(host: @host) do
            cookies[::Preference::CookieName.access] = token

            patch sign_com_preference_region_path,
                  params: { preference_region: { option_id: "us" } },
                  headers: as_customer_headers(@customer, host: @host)
          end

          assert_redirected_to edit_sign_com_preference_region_url(ri: "us")

          preference.reload
          @customer.customer_preference.reload

          assert_equal ComPreferenceRegionOption::US, preference.com_preference_region.option_id
          assert_equal "us", @customer.customer_preference.region
        end
      end
    end
  end
end
