# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      module Display
        class R18DisplayStoppersControllerTest < ActionDispatch::IntegrationTest
          fixtures :clients, :client_preferences

          setup do
            @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
            @user = clients(:one)
            host! @host
          end

          test "edit renders unset approved and deny choices" do
            get edit_sign_app_preference_display_r18_display_stopper_url(ri: "jp", lx: "en"),
                headers: as_user_headers(@user, host: @host)

            assert_response :success
            assert_select "select[name='preference_r18_display_stopper[option_id]'] option", text: "Unset"
            assert_select "select[name='preference_r18_display_stopper[option_id]'] option", text: "Approved"
            assert_select "select[name='preference_r18_display_stopper[option_id]'] option", text: "Deny"
            assert_select "option[selected][value='0']", count: 1
          end

          test "PATCH update stores approved preference" do
            patch sign_app_preference_display_r18_display_stopper_url(ri: "jp", lx: "en"),
                  params: { preference_r18_display_stopper: { option_id: "1" } },
                  headers: as_user_headers(@user, host: @host)

            assert_response :redirect

            preference = @user.reload.user_preference

            assert_equal ClientPreferenceR18DisplayStopperOption::APPROVED,
                         preference.client_preference_r18_display_stopper.option_id
          end

          test "PATCH update keeps unset preference when submitted as zero" do
            patch sign_app_preference_display_r18_display_stopper_url(ri: "jp", lx: "en"),
                  params: { preference_r18_display_stopper: { option_id: "0" } },
                  headers: as_user_headers(@user, host: @host)

            assert_response :redirect

            preference = @user.reload.user_preference

            assert_equal ClientPreferenceR18DisplayStopperOption::NOTHING,
                         preference.client_preference_r18_display_stopper.option_id
          end
        end
      end
    end
  end
end
