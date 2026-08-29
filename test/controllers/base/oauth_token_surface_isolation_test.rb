# typed: false
# frozen_string_literal: true

require "test_helper"

# The app / com / org token endpoints are independent trust boundaries. An authorization code
# issued on one surface must not be redeemable through another surface's `/oauth/token`, and the
# rejection must be indistinguishable from an unknown code so the client cannot learn that the
# code exists elsewhere.
class BaseOauthTokenSurfaceIsolationTest < ActionDispatch::IntegrationTest
  SURFACES = {
    "client" => { realm: "client", host_env: "PUBLIC_BASE_SERVICE_URL", host_default: "base.app.localhost" },
    "visitor" => { realm: "visitor", host_env: "PUBLIC_BASE_CORPORATE_URL", host_default: "base.com.localhost" },
    "operator" => { realm: "operator", host_env: "PUBLIC_BASE_STAFF_URL", host_default: "base.org.localhost" },
  }.freeze

  # The wrong-surface rejection must reuse the unknown-code failure verbatim.
  UNKNOWN_CODE_ERROR_DESCRIPTION = "Authorization code not found"

  setup do
    @previous_client_assertion_replay_store = OidcClientAssertionJwt.replay_store
    OidcClientAssertionJwt.replay_store = ActiveSupport::Cache::MemoryStore.new
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)
    @client = OidcClientRegistry.find("core-next-rp")
  end

  teardown do
    OidcClientAssertionJwt.replay_store = @previous_client_assertion_replay_store
  end

  # --- matching surface succeeds ---

  SURFACES.each_key do |resource_type|
    test "#{resource_type} authorization code is redeemed at its own surface token endpoint" do
      code_record = issue_code_for(resource_type)

      post_token(resource_type, code_record)

      assert_response :ok
      body = response.parsed_body

      assert_predicate body["access_token"], :present?
      assert_predicate body["refresh_token"], :present?
      assert_predicate body["id_token"], :present?
      assert_predicate code_record.reload, :consumed?
    end
  end

  # --- every wrong-surface pairing is rejected ---

  SURFACES.each_key do |code_resource_type|
    SURFACES.each_key do |endpoint_resource_type|
      next if code_resource_type == endpoint_resource_type

      test "#{code_resource_type} authorization code cannot be redeemed at the " \
           "#{endpoint_resource_type} surface token endpoint" do
        code_record = issue_code_for(code_resource_type)

        post_token(endpoint_resource_type, code_record)

        assert_response :bad_request
        body = response.parsed_body

        assert_equal "invalid_grant", body["error"]
        assert_equal UNKNOWN_CODE_ERROR_DESCRIPTION, body["error_description"]
        assert_nil body["access_token"]
        assert_not_predicate code_record.reload, :consumed?
        assert_not_predicate code_record, :revoked?
      end
    end
  end

  test "wrong-surface rejection is indistinguishable from an unknown code" do
    code_record = issue_code_for("operator")

    post_token("client", code_record)
    mismatch_body = response.parsed_body
    mismatch_status = response.status

    post_token("client", nil, code: "nonexistent-#{SecureRandom.hex(8)}")

    assert_equal response.status, mismatch_status
    assert_equal response.parsed_body["error"], mismatch_body["error"]
    assert_equal response.parsed_body["error_description"], mismatch_body["error_description"]
  end

  private

  def host_for(resource_type)
    surface = SURFACES.fetch(resource_type)
    ENV.fetch(surface.fetch(:host_env), surface.fetch(:host_default))
  end

  def redirect_uri_for(resource_type)
    @client.redirect_uris_by_realm.fetch(SURFACES.fetch(resource_type).fetch(:realm)).first
  end

  def token_endpoint_url(resource_type)
    case resource_type
    when "client" then base_app_oauth_token_url(host: host_for("client"))
    when "visitor" then base_com_oauth_token_url(host: host_for("visitor"))
    when "operator" then base_org_oauth_token_url(host: host_for("operator"))
    else raise ArgumentError, "unsupported resource_type: #{resource_type.inspect}"
    end
  end

  # The client authenticates legitimately against whichever endpoint it calls, so nothing but the
  # surface scoping of the authorization-code lookup can reject a wrong-surface redemption.
  def post_token(endpoint_resource_type, code_record, code: nil)
    token_url = token_endpoint_url(endpoint_resource_type)

    with_oidc_client_key(@client.jwt_namespace) do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      post(
        token_url,
        params: {
          grant_type: "authorization_code",
          code: code || code_record.code,
          redirect_uri: code_record ? code_record.redirect_uri : redirect_uri_for(endpoint_resource_type),
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: assertion,
          code_verifier: @code_verifier,
        },
      )
    end
  end

  def issue_code_for(resource_type)
    case resource_type
    when "client" then issue_client_code!
    when "visitor" then issue_visitor_code!
    when "operator" then issue_operator_code!
    else raise ArgumentError, "unsupported resource_type: #{resource_type.inspect}"
    end
  end

  def issue_client_code!
    user = clients(:one)

    ClientAuthorizationCode.issue!(
      user: user,
      client_token: ClientToken.create!(user: user),
      client_id: "core-next-rp",
      redirect_uri: redirect_uri_for("client"),
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "client_nonce",
      scope: "openid profile email",
    )
  end

  def issue_operator_code!
    staff = operators(:one)

    OperatorAuthorizationCode.issue!(
      staff: staff,
      operator_token: OperatorToken.create!(staff: staff),
      client_id: "core-next-rp",
      redirect_uri: redirect_uri_for("operator"),
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "operator_nonce",
      scope: "openid profile email",
    )
  end

  def issue_visitor_code!
    visitor = create_visitor!

    VisitorAuthorizationCode.issue!(
      visitor: visitor,
      visitor_token: VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB),
      client_id: "core-next-rp",
      redirect_uri: redirect_uri_for("visitor"),
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
      scope: "openid profile email",
    )
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  def with_oidc_client_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
