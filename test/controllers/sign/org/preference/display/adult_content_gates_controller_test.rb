# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      module Display
        class AdultContentGatesControllerTest < ActionDispatch::IntegrationTest
          fixtures :operators, :operator_preferences

          setup do
            @host = ENV.fetch("SIGN_STAFF_URL", "id.umaxica.org")
            @staff = operators(:one)
            host! @host
          end

          test "preferences index links to r18 display stopper settings" do
            get sign_org_preference_url(ri: "jp", lx: "en"),
                headers: as_staff_headers(@staff, host: @host)

            assert_response :success
            assert_select "a[href*=?]", edit_sign_org_preference_display_adult_content_gate_path
          end

          test "edit renders unset approved and deny choices" do
            get edit_sign_org_preference_display_adult_content_gate_url(ri: "jp", lx: "en"),
                headers: as_staff_headers(@staff, host: @host)

            assert_response :success
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='0']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='1']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='2']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='2']", count: 1
          end

          test "PATCH update stores approved preference" do
            patch sign_org_preference_display_adult_content_gate_url(ri: "jp", lx: "en"),
                  params: { preference_adult_content_gate: { option_id: "1" } },
                  headers: as_staff_headers(@staff, host: @host)

            assert_response :redirect

            preference = @staff.reload.staff_preference

            assert_equal OperatorPreferenceAdultContentGateOption::APPROVED,
                         preference.operator_preference_adult_content_gate.option_id
          end
        end
      end
    end
  end
end
