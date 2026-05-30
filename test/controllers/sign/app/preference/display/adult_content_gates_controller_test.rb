# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      module Display
        class AdultContentGatesControllerTest < ActionDispatch::IntegrationTest
          fixtures :clients, :client_preferences

          setup do
            @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
            @user = clients(:one)
            host! @host
          end

          test "edit renders unset approved and deny choices" do
            get edit_sign_app_preference_display_adult_content_gate_url(ri: "jp", lx: "en"),
                headers: as_user_headers(@user, host: @host)

            assert_response :success
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='0']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='1']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='2']"
            assert_select "select[name='preference_adult_content_gate[option_id]'] option[value='0']", count: 1
          end

          test "PATCH update stores approved preference" do
            patch sign_app_preference_display_adult_content_gate_url(ri: "jp", lx: "en"),
                  params: { preference_adult_content_gate: { option_id: "1" } },
                  headers: as_user_headers(@user, host: @host)

            assert_response :redirect

            preference = @user.reload.user_preference

            assert_equal ClientPreferenceAdultContentGateOption::APPROVED,
                         preference.client_preference_adult_content_gate.option_id
          end

          test "PATCH update keeps unset preference when submitted as zero" do
            patch sign_app_preference_display_adult_content_gate_url(ri: "jp", lx: "en"),
                  params: { preference_adult_content_gate: { option_id: "0" } },
                  headers: as_user_headers(@user, host: @host)

            assert_response :redirect

            preference = @user.reload.user_preference

            assert_equal ClientPreferenceAdultContentGateOption::NOTHING,
                         preference.client_preference_adult_content_gate.option_id
          end
        end
      end
    end
  end
end
