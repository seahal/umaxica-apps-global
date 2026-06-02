# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      module Display
        class AdultContentGatesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @host = ENV.fetch("SIGN_CORPORATE_URL", "id.umaxica.com")
            @visitor = create_verified_visitor_with_email(
              email_address: "preference-r18-#{SecureRandom.hex(4)}@example.com",
            )
            @visitor.visitor_telephones.create!(
              number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
              visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
            )
            host! @host
          end

          test "preferences index links to r18 display stopper settings" do
            get sign_com_preference_url(ri: "jp", lx: "en"),
                headers: as_visitor_headers(@visitor, host: @host)

            assert_response :success
            assert_select "a[href*=?]", edit_sign_com_preference_adult_content_gate_path
          end

          test "edit renders unset approved and deny choices" do
            get edit_sign_com_preference_adult_content_gate_url(ri: "jp", lx: "en"),
                headers: as_visitor_headers(@visitor, host: @host)

            assert_response :success
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='0']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='1']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='2']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='0']", count: 1
          end

          test "PATCH update stores approved preference" do
            patch sign_com_preference_adult_content_gate_url(ri: "jp", lx: "en"),
                  params: { preference_adult_content_gate: { option_id: "1" } },
                  headers: as_visitor_headers(@visitor, host: @host)

            assert_response :redirect

            preference = @visitor.reload.visitor_preference

            assert_equal VisitorPreferenceAdultContentGateOption::APPROVED,
                         preference.visitor_preference_adult_content_gate.option_id
          end
        end
      end
    end
  end
end
