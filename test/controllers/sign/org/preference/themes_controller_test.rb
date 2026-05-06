# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      class ThemesControllerTest < ActionDispatch::IntegrationTest
        fixtures :staffs, :staff_preferences

        setup do
          @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          @staff = staffs(:one)
          host! @host
        end

        test "PATCH update returns updated preference payload and syncs auth preference" do
          patch sign_org_preference_theme_path,
                params: { preference_colortheme: { option_id: "dr" } },
                headers: as_staff_headers(@staff, host: @host),
                as: :json

          assert_response :ok
          assert_equal "dr", response.parsed_body.dig("preference", "ct")
          assert_equal "ja", response.parsed_body.dig("preference", "lx")
          assert_includes response.headers["Set-Cookie"].to_s, "#{::Preference::CookieName.access}="

          @staff.staff_preference.reload

          assert_equal "dr", @staff.staff_preference.theme
        end
      end
    end
  end
end
