# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class SignInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end

      test "should get new" do
        get new_sign_com_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "h1", text: I18n.t("sign.com.authentication.new.page_title")
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://id.umaxica.com/configuration/sessions?ri=jp", padding: false)

        get new_sign_com_sign_in_url(ri: "jp", pt: pt), headers: { "Host" => @host }

        assert_response :success
        assert_select "a[href=?]", new_sign_com_in_email_path(ri: "jp")
        assert_select "a[href=?]", new_sign_com_in_passkey_path(ri: "jp")
        assert_select "a[href=?]", new_sign_com_in_secret_credential_path(ri: "jp")
      end

      test "does not show social login buttons" do
        get new_sign_com_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action='/auth/google_app']", count: 0
        assert_select "form[action='/auth/google_org']", count: 0
        assert_select "form[action='/auth/apple']", count: 0
      end

      test "redirects to dashboard when logged in" do
        visitor = create_verified_visitor_with_email(email_address: "com-in-logged-in@example.com")
        visitor.visitor_telephones.create!(
          number: "+15550002225",
          visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
        )

        get new_sign_com_sign_in_url(ri: "jp"), headers: as_visitor_headers(visitor, host: @host)

        assert_redirected_to sign_com_dashboard_url(ri: "jp")
      end
    end
  end
end
