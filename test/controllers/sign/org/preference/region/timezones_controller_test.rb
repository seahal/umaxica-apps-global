# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      module Region
        class TimezonesControllerTest < ActionDispatch::IntegrationTest
          fixtures :staffs, :staff_preferences

          setup do
            @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
            @staff = staffs(:one)
            host! @host
          end

          test "PATCH update syncs timezone to staff preference" do
            patch sign_org_preference_region_timezone_path,
                  params: { preference_timezone: { option_id: OrgPreferenceTimezoneOption::ETC_UTC } },
                  headers: as_staff_headers(@staff, host: @host)

            assert_redirected_to edit_sign_org_preference_region_timezone_url

            @staff.staff_preference.reload

            assert_equal "Etc/UTC", @staff.staff_preference.timezone
          end
        end
      end
    end
  end
end
