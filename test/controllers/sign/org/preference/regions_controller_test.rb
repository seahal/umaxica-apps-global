# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      class RegionsControllerTest < ActionDispatch::IntegrationTest
        fixtures :staffs, :staff_preferences

        setup do
          @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          @staff = staffs(:one)
          host! @host
        end

        test "PATCH update syncs region to staff preference" do
          patch sign_org_preference_region_path,
                params: { preference_region: { option_id: "us" } },
                headers: as_staff_headers(@staff, host: @host)

          assert_redirected_to edit_sign_org_preference_region_url(ri: "us")

          @staff.staff_preference.reload

          assert_equal "us", @staff.staff_preference.region
        end
      end
    end
  end
end
