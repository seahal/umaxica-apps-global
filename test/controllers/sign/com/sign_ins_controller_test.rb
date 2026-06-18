# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class SignInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end

      test "direct entry normalizes to acme com authorization" do
        get sign_com_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :redirect

        uri = URI.parse(jump_rt_url_from_location(response.location))
        query = Rack::Utils.parse_nested_query(uri.query.to_s)

        assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), uri.host
        assert_equal "/oauth/authorize", uri.path
        assert_equal "sign-rp", query["client_id"]
        assert_equal "signin", query["screen_hint"]
        assert_nil session[:oidc_authorization_login_challenge]
      end

      test "valid login challenge renders local ceremony" do
        get sign_com_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        assert_select "h1", text: I18n.t("sign.com.authentication.new.page_title")
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://id.umaxica.com/settings/sessions?ri=jp", padding: false)

        get sign_com_sign_in_url(ri: "jp", pt: pt, login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_select "a[href=?]", new_sign_com_sign_in_email_path(ri: "jp")
        assert_select "a[href=?]", new_sign_com_sign_in_passkey_path(ri: "jp")
        assert_select "a[href=?]", new_sign_com_sign_in_secret_credential_path(ri: "jp")
      end

      test "does not show social login buttons" do
        get sign_com_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action='/auth/google_app']", count: 0
        assert_select "form[action='/auth/apple']", count: 0
        assert_select "form[action*=?]", "/social/auth/", count: 0
        assert_select "form[action*=?]", "/auth/google", count: 0
      end

      test "does not show temporary google signin button when legacy flag is set" do
        with_env("COM_#{"GOOGLE"}_SIGNIN_ENABLED" => "true") do
          get sign_com_sign_in_url(ri: "jp", login_challenge: login_challenge),
              headers: { "Host" => @host }
        end

        assert_response :success
        assert_select "form[action*=?]", "/social/auth/google", count: 0
        assert_select "form[action*=?]", "/auth/google", count: 0
      end

      test "redirects to dashboard when logged in" do
        visitor = create_verified_visitor_with_email(email_address: "com-in-logged-in@example.com")
        visitor.visitor_telephones.create!(
          number: "+15550002225",
          visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
        )

        get sign_com_sign_in_url(ri: "jp"), headers: as_visitor_headers(visitor, host: @host)

        assert_redirected_to acme_com_dashboard_url(
                               ri: "jp",
                               host: ENV.fetch(
                                 "ACME_CORPORATE_URL", "www.com.localhost",
                               ),
                             )
      end

      private

      def login_challenge
        OidcAuthorizationTransactionService.issue!(
          surface: "com",
          intent: "sign_in",
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

      def with_env(values)
        original = values.keys.index_with { |key| ENV[key] }
        values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
        yield
      ensure
        original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      end
    end
  end
end
