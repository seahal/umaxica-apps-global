# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        fixtures :staffs, :staff_preferences

        setup do
          @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          @staff = staffs(:one)
          host! @host
        end

        test "DELETE destroy resets staff preference defaults" do
          @staff.staff_preference.update!(
            consented: true,
            functional: true,
            performant: true,
            targetable: true,
            region: "us",
            timezone: "UTC",
            theme: "dr",
          )

          delete sign_org_preference_reset_path,
                 params: { confirm_reset: "1" },
                 headers: as_staff_headers(@staff, host: @host)

          assert_redirected_to edit_sign_org_preference_reset_path

          @staff.staff_preference.reload

          assert_not @staff.staff_preference.consented
          assert_not @staff.staff_preference.functional
          assert_not @staff.staff_preference.performant
          assert_not @staff.staff_preference.targetable
          assert_equal "jp", @staff.staff_preference.region
          assert_equal "Asia/Tokyo", @staff.staff_preference.timezone
          assert_equal "sy", @staff.staff_preference.theme
        end
      end
    end
  end
end
