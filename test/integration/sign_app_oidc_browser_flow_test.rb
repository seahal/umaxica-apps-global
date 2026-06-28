# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppOidcBrowserFlowTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  fixtures_none!
  self.use_transactional_tests = false

  setup do
    load_jump_rt_env!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  teardown do
    cleanup_sign_oidc_browser_flow_data!
  end

  test "sign app settings auth-required sso resolves an existing acme session and returns to settings" do # rubocop:disable Minitest/MultipleAssertions
    with_acme_oidc_client_key do
      sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      email = "sign-oidc-browser-flow-#{SecureRandom.hex(4)}@example.com"
      @user = create_verified_user_with_email(email_address: email)
      current_session =
        ClientToken.create!(
          user: @user,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
        )
      @current_session_id = current_session.id
      acme_headers = as_user_headers(@user, host: acme_host, session_public_id: current_session.public_id)
      acme_session = open_session
      acme_session.host!(acme_host)
      acme_session.https!

      host! sign_host
      https!
      get auth_app_settings_url(ri: "jp"), headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(response.location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path
      assert_not_equal "jump.umaxica.net", authorize_uri.host
      assert_equal "sign-rp", authorize_query.fetch("client_id")
      assert_nil authorize_query["screen_hint"]
      assert_predicate session[AuthenticationBase::DEFAULT_PT_SESSION_KEY], :present?
      assert_predicate session[:oidc_state], :present?
      assert_predicate session[:oidc_nonce], :present?
      assert_predicate session[:oidc_code_verifier], :present?

      root_token_count = ClientToken.where(user_id: @user.id).count
      usage_count = ClientTokenUsage.count

      AppTicketRecord.connected_to(role: :writing) do
        acme_session.get("/oauth/authorize", params: authorize_query, headers: acme_headers)

        assert_predicate acme_session.response, :redirect?
        callback_uri = URI.parse(jump_rt_url_from_location(acme_session.response.location))
        callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

        assert_equal "/oidc/callback", callback_uri.path
        assert_predicate callback_query["code"], :present?
        assert_equal authorize_query.fetch("state"), callback_query.fetch("state")
        code_record = ClientAuthorizationCode.find_by!(code: callback_query.fetch("code"))

        assert_equal @user.id, code_record.user_id
        assert_equal @current_session_id, code_record.client_token_id
        assert_predicate code_record.client_token, :present?
        assert_predicate code_record.resource, :present?

        host! sign_host
        get sign_app_oidc_callback_url, params: callback_query, headers: browser_headers
      end

      assert_response :redirect
      assert_equal auth_app_settings_url(ri: "jp", host: sign_host), response.location
      assert_includes response.headers["Set-Cookie"].to_s, "#{AuthenticationBase::ACCESS_COOKIE_KEY}="
      assert_includes response.headers["Set-Cookie"].to_s, "#{AuthenticationBase::REFRESH_COOKIE_KEY}="
      assert_equal root_token_count, ClientToken.where(user_id: @user.id).count
      assert_equal usage_count + 1, ClientTokenUsage.count

      get auth_app_settings_url(ri: "jp"), headers: browser_headers

      assert_response :success
      assert_select "h1", "Settings"
      assert_empty ClientOidcAuthorizationTransaction.pending.where(
        actor_ref: nil,
        session_ref: nil,
        authenticated_at: nil,
      )
      assert_nil session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
      assert_nil session[:oidc_state]
      assert_nil session[:oidc_nonce]
      assert_nil session[:oidc_code_verifier]
    end
  end

  private

  def cleanup_sign_oidc_browser_flow_data!
    return unless defined?(@user) && @user.present?

    AppTicketRecord.connected_to(role: :writing) do
      ClientAuthorizationCode.where(
        client_id: "sign-rp",
        client_token_id: @current_session_id,
      ).delete_all if defined?(@current_session_id)
      ClientTokenUsage.where(client_token_id: @current_session_id).delete_all if defined?(@current_session_id)
      ClientOidcConnection.where(user_id: @user.id, client_id: "sign-rp").delete_all
      ClientToken.where(id: @current_session_id).find_each(&:destroy!) if defined?(@current_session_id)
    end

    AppPrincipalRecord.connected_to(role: :writing) do
      ClientEmail.where(user_id: @user.id).find_each(&:destroy!)
      Client.where(id: @user.id).find_each(&:destroy!)
    end
  end

  def with_acme_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = "acme-app-oidc-test"
    ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end
end
