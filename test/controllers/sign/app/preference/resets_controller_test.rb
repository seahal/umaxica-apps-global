# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        fixtures :clients

        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @user = clients(:one)
          host! @host
        end

        test "DELETE destroy redirects signed-in reset to app preference index" do
          delete sign_app_preference_reset_path,
                 params: { confirm_reset: "1" },
                 headers: as_user_headers(@user, host: @host)

          assert_response :see_other
          assert_redirected_to sign_app_preference_path
        end

        test "DELETE destroy redirects anonymous reset to app preference index" do
          delete sign_app_preference_reset_path,
                 params: { confirm_reset: "1" }

          assert_response :see_other
          assert_redirected_to sign_app_preference_path
        end
      end
    end
  end
end
