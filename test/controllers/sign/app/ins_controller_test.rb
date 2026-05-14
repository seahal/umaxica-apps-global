# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    class InsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      test "should get new with authentication links" do
        get new_sign_app_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success

        query = {}

        assert_select "a[href=?]", new_sign_app_in_email_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.email")
        assert_select "a[href=?]", new_sign_app_in_passkey_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.passkey")
        assert_select "a[href=?]", new_sign_app_in_secret_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.secret")
      end

      test "authentication links carry rt" do
        rt = Base64.urlsafe_encode64("https://id.umaxica.app/configuration/sessions?ri=jp", padding: false)

        get new_sign_app_in_url(ri: "jp", rt: rt), headers: { "Host" => @host }

        assert_response :success
        assert_select "a[href=?]", new_sign_app_in_email_path(rt: rt, ri: "jp")
        assert_select "a[href=?]", new_sign_app_in_passkey_path(rt: rt, ri: "jp")
        assert_select "a[href=?]", new_sign_app_in_secret_path(rt: rt, ri: "jp")
      end

      test "sign up link includes rt when rt is present" do
        get new_sign_app_in_url(ri: "jp", rt: "abc"), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp&amp;rt=abc"
      end

      test "sign up link includes only ri when rt is absent" do
        get new_sign_app_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp"
        assert_not_includes response.body, "rt="
      end

      test "sign up link preserves encoded-like rt value safely" do
        rt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        get new_sign_app_in_url(ri: "jp", rt: rt), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp&amp;rt="
        assert_includes response.body, "rt=aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%253D%253D"
      end

      test "should render in english when lx=en" do
        get new_sign_app_in_url(lx: "en", ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "html[lang=en]"
        assert_select "a", text: /Need an account/
      end

      test "shows social login buttons" do
        get new_sign_app_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action=?]",
                      continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp"),
                      count: 1
        assert_select "form[action=?]",
                      continue_sign_app_social_authentication_path(provider: "apple", ri: "jp"),
                      count: 1
      end

      test "redirects to dashboard when logged in" do
        user = users(:one)

        get new_sign_app_in_url(ri: "jp"), headers: as_user_headers(user, host: @host)

        assert_redirected_to sign_app_dashboard_url(ri: "jp")
      end
    end
  end
end
