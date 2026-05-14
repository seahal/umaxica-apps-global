# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module Org
    module Preference
      class CookiesControllerTest < ActionDispatch::IntegrationTest
        include PreferenceJwtHelper

        fixtures :staffs, :staff_preferences,
                 :org_preference_theme_options, :org_preferences,
                 :org_preference_cookies

        setup do
          @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          @staff = staffs(:one)
          host! @host
        end

        test "PATCH update returns updated preference payload and syncs consent" do
          patch sign_org_preference_cookie_path,
                params: {
                  preference_cookie: {
                    consented: true,
                    functional: true,
                    performant: true,
                    targetable: false,
                  },
                },
                headers: as_staff_headers(@staff, host: @host),
                as: :json

          assert_response :ok
          assert response.parsed_body.dig("preference", "consented")
          assert response.parsed_body.dig("preference", "functional")
          assert_includes response.headers["Set-Cookie"].to_s, "#{::Preference::CookieName.access}="

          @staff.staff_preference.reload

          assert @staff.staff_preference.consented
          assert @staff.staff_preference.functional
          assert @staff.staff_preference.performant
          assert_not @staff.staff_preference.targetable
        end

        test "PATCH update persists even when preference access token cannot be reissued" do
          ::Preference::Token.stub(:encode, nil) do
            patch sign_org_preference_cookie_path,
                  params: {
                    preference_cookie: {
                      consented: true,
                      functional: true,
                      performant: true,
                      targetable: false,
                    },
                  },
                  headers: as_staff_headers(@staff, host: @host),
                  as: :json
          end

          assert_response :ok

          @staff.staff_preference.reload

          assert @staff.staff_preference.consented
          assert @staff.staff_preference.functional
          assert @staff.staff_preference.performant
          assert_not @staff.staff_preference.targetable
        end
      end
    end
  end
end
