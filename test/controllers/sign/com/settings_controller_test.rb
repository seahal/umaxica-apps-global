# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class SettingsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
        @visitor = create_verified_visitor_with_email(email_address: "config-#{SecureRandom.hex(4)}@example.com")
        VisitorTelephone.create!(
          visitor: @visitor,
          raw_number: "+81901111#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
          visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
        )
        @headers = as_visitor_headers(@visitor, host: @host)
      end

      test "should get show when logged in" do
        get sign_com_settings_url(ri: "jp"), headers: @headers

        assert_response :success
        # Assert no social links
        assert_select "a[href*='google']", count: 0
        assert_select "a[href*='apple']", count: 0

        # Assert existing com links
        assert_select "a[href^=?]", sign_com_settings_emails_path(ri: "jp")
        assert_select "a[href^=?]", sign_com_settings_telephones_path(ri: "jp")
        assert_select "a[href^=?]", sign_com_settings_birthdate_path(ri: "jp")
        assert_select "a[href^=?]", sign_com_settings_mfa_challenge_path(ri: "jp")
      end

      test "should redirect show when not logged in" do
        get sign_com_settings_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :redirect
        assert_match %r{\Ahttps://id\.umaxica\.com/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
      end

      test "edit route is not available" do
        get "/settings/edit", headers: { "Host" => @host }

        assert_response :not_found
      end
    end
  end
end
