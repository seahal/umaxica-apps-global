# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
        @customer = create_verified_customer_with_email(email_address: "config-#{SecureRandom.hex(4)}@example.com")
        CustomerTelephone.create!(
          customer: @customer,
          raw_number: "+81901111#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
          customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
        )
        @headers = as_customer_headers(@customer, host: @host)
      end

      test "should get show when logged in" do
        get sign_com_configuration_url(ri: "jp"), headers: @headers

        assert_response :success
        # Assert no social links
        assert_select "a[href*='google']", count: 0
        assert_select "a[href*='apple']", count: 0

        # Assert existing com links
        assert_select "a[href^=?]", sign_com_configuration_emails_path(ri: "jp")
        assert_select "a[href^=?]", sign_com_configuration_telephones_path(ri: "jp")
        assert_select "a[href^=?]", sign_com_configuration_challenge_path(ri: "jp")
      end

      test "should redirect show when not logged in" do
        get sign_com_configuration_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :redirect
        assert_redirected_to %r{/sign/in/new\?ri=jp}
      end
    end
  end
end
