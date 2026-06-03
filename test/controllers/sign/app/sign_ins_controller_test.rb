# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    class SignInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      test "should get new with authentication links" do
        get new_sign_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success

        query = {}

        assert_select "a[href=?]", new_sign_app_in_email_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.email")
        assert_select "a[href=?]", new_sign_app_in_passkey_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.passkey")
        assert_select "a[href=?]", new_sign_app_in_secret_credential_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.secret_credential")
      end

      test "should get new with existing preference refresh cookie" do
        token, verifier = AppPreference.generate_refresh_token(public_id: "app-pref-existing")
        preference = AppPreference.create!(
          public_id: "app-pref-existing",
          token_digest: AppPreference.digest_refresh_token(verifier),
          jti: SecureRandom.uuid,
          status_id: AppPreferenceStatus::NOTHING,
          binding_method_id: AppPreferenceBindingMethod::LEGACY,
          dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
          expires_at: 20.years.from_now,
        )
        AppPreferenceCookie.create!(preference: preference)
        cookies[::Preference::CookieName.refresh(surface: :app)] = token

        get new_sign_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://id.umaxica.app/settings/sessions?ri=jp", padding: false)

        get new_sign_app_sign_in_url(ri: "jp", pt: pt), headers: { "Host" => @host }

        assert_response :success
        assert_select "a[href=?]", new_sign_app_in_email_path(ri: "jp")
        assert_select "a[href=?]", new_sign_app_in_passkey_path(ri: "jp")
        assert_select "a[href=?]", new_sign_app_in_secret_credential_path(ri: "jp")
      end

      test "sign up link includes pt when pt is present" do
        get new_sign_app_sign_in_url(ri: "jp", pt: "abc"), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp"
        assert_not_includes response.body, "pt=abc"
      end

      test "sign up link includes only ri when pt is absent" do
        get new_sign_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp"
        assert_not_includes response.body, "pt="
      end

      test "sign up link preserves encoded-like pt value safely" do
        pt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        get new_sign_app_sign_in_url(ri: "jp", pt: pt), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up/new?ri=jp"
        assert_not_includes response.body, "pt="
      end

      test "should render in english when lx=en" do
        get new_sign_app_sign_in_url(lx: "en", ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "html[lang=en]"
        assert_select "a", text: /Need an account/
      end

      test "shows social login buttons" do
        get new_sign_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action=?][data-turbo=?]",
                      continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp"),
                      "false",
                      count: 1
        assert_select "form[action=?][data-turbo=?]",
                      continue_sign_app_social_authentication_path(provider: "apple", ri: "jp"),
                      "false",
                      count: 1
      end

      test "redirects to dashboard when logged in" do
        user = clients(:one)

        get new_sign_app_sign_in_url(ri: "jp"), headers: as_user_headers(user, host: @host)

        assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
      end
    end
  end
end
