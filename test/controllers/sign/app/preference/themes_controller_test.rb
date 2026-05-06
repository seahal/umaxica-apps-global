# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class ThemesControllerTest < ActionDispatch::IntegrationTest
        fixtures :users, :user_preferences

        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @user = users(:one)
          host! @host
        end

        test "PATCH update returns updated preference payload and syncs auth preference" do
          patch sign_app_preference_theme_path,
                params: { preference_colortheme: { option_id: "dr" } },
                headers: as_user_headers(@user, host: @host),
                as: :json

          assert_response :ok
          assert_equal "dr", response.parsed_body.dig("preference", "ct")
          assert_equal "ja", response.parsed_body.dig("preference", "lx")
          assert_includes response.headers["Set-Cookie"].to_s, "#{::Preference::CookieName.access}="

          @user.user_preference.reload

          assert_equal "dr", @user.user_preference.theme
        end
      end
    end
  end
end
