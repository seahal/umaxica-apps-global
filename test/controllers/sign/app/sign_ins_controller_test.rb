# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    class SignInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      test "direct entry normalizes to acme app authorization" do
        get sign_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :redirect

        uri = URI.parse(response.location)
        query = Rack::Utils.parse_nested_query(uri.query.to_s)

        assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
        assert_equal "/oauth/authorize", uri.path
        assert_not_equal "jump.umaxica.net", uri.host
        assert_equal "sign-rp", query["client_id"]
        assert_equal "signin", query["screen_hint"]
        assert_nil session[:oidc_authorization_login_challenge]
      end

      test "local ceremony renders authentication links" do
        get sign_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success

        query = {}

        assert_select "a[href=?]", new_sign_app_sign_in_email_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.email")
        assert_select "a[href=?]", new_sign_app_sign_in_passkey_path(query, ri: "jp"),
                      I18n.t("sign.app.authentication.new.links.passkey")
        assert_select "a[href=?]", new_sign_app_sign_in_secret_credential_path(query, ri: "jp"),
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
        cookies[::PreferenceCookieName.refresh(surface: :app)] = token

        get sign_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://id.umaxica.app/settings/sessions?ri=jp", padding: false)

        get sign_app_sign_in_url(ri: "jp", pt: pt, login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_select "a[href=?]", new_sign_app_sign_in_email_path(ri: "jp")
        assert_select "a[href=?]", new_sign_app_sign_in_passkey_path(ri: "jp")
        assert_select "a[href=?]", new_sign_app_sign_in_secret_credential_path(ri: "jp")
      end

      test "sign up link includes pt when pt is present" do
        get sign_app_sign_in_url(ri: "jp", pt: "abc", login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up?ri=jp"
        assert_not_includes response.body, "pt=abc"
      end

      test "sign up link includes only ri when pt is absent" do
        get sign_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up?ri=jp"
        assert_not_includes response.body, "pt="
      end

      test "sign up link preserves encoded-like pt value safely" do
        pt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        get sign_app_sign_in_url(ri: "jp", pt: pt, login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_includes response.body, "/sign/up?ri=jp"
        assert_not_includes response.body, "pt="
      end

      test "should render in english when lx=en" do
        get sign_app_sign_in_url(lx: "en", ri: "jp", login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_select "html[lang=en]"
        assert_select "a", text: /Need an account/
      end

      test "shows social login buttons" do
        get sign_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action=?][data-turbo=?]",
                      sign_app_social_google_sign_in_path(ri: "jp"),
                      "false",
                      count: 1
        assert_select "form[action=?][data-turbo=?]",
                      sign_app_social_apple_sign_in_path(ri: "jp"),
                      "false",
                      count: 1
      end

      test "rejects direct entry when logged in" do
        user = clients(:one)

        get sign_app_sign_in_url(ri: "jp"), headers: as_user_headers(user, host: @host)

        assert_response :redirect
        assert_redirected_to sign_app_dashboard_url(ri: "jp", host: @host)
      end

      test "logged in entry with login challenge resumes acme authorization" do
        user = clients(:one)
        issuance =
          OidcAuthorizationTransactionService.issue!(
            surface: "app",
            intent: "sign_in",
            params: authorize_params,
          )
        headers = as_user_headers(user, host: @host)

        get sign_app_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
            headers: headers

        assert_response :redirect

        redirect_uri = URI.parse(response.location)
        redirect_query = Rack::Utils.parse_nested_query(redirect_uri.query.to_s)
        transaction = issuance.transaction.reload

        assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), redirect_uri.host
        assert_equal "/oauth/authorize", redirect_uri.path
        assert_equal issuance.transaction.login_challenge, redirect_query["login_challenge"]
        assert_predicate transaction, :authenticated?
        assert_equal user.public_id, transaction.actor_ref
        assert_equal headers.fetch("X-TEST-SESSION-PUBLIC-ID"), transaction.session_ref
        assert_nil session[:oidc_authorization_login_challenge]
        assert_nil flash[:alert]
      end

      private

      def login_challenge(intent: "sign_in")
        OidcAuthorizationTransactionService.issue!(
          surface: "app",
          intent: intent,
          params: authorize_params,
        ).transaction.login_challenge
      end

      def authorize_params
        {
          response_type: "code",
          client_id: "core-next-rp",
          redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        }
      end
    end
  end
end
