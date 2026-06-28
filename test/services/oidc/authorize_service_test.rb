# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizeCoordinatorTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @user_session_token = ClientToken.create!(user: @user)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = OidcClientRegistry.find("core-next-rp")
    @redirect_uri = @client.redirect_uris.first
  end

  test "issues authorization code and returns redirect URL" do
    result = authorize_service_call(
      params: valid_params,
      resource: @user,
    )

    assert_predicate result, :success?
    assert_not_nil result.redirect_url
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    expected_uri = URI.parse(@redirect_uri)

    assert_equal "#{expected_uri.scheme}://#{expected_uri.host}#{expected_uri.path}",
                 "#{uri.scheme}://#{uri.host}#{uri.path}"
    assert_predicate query["code"], :present?
    assert_equal "test_state", query["state"]
  end

  test "fails for missing response_type" do
    result = authorize_service_call(
      params: valid_params.except(:response_type),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for wrong response_type" do
    result = authorize_service_call(
      params: valid_params.merge(response_type: "token"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for unknown client_id" do
    result = authorize_service_call(
      params: valid_params.merge(client_id: "unknown"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "unauthorized_client", result.error
  end

  test "fails for unregistered redirect_uri" do
    result = authorize_service_call(
      params: valid_params.merge(redirect_uri: "https://evil.com/callback"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "rejects malicious redirect_uri values" do
    malicious_redirect_uris = [
      "https://evil.example",
      "//evil.example",
      "%2f%2fevil.example",
      "https://rp.example.com.evil.example",
      "https://rp.example.com@evil.example",
      "https://evil.example/rp.example.com",
      "javascript:alert(1)",
      "data:text/html,...",
      "\\evil.example",
    ]

    malicious_redirect_uris.each do |redirect_uri|
      result = authorize_service_call(
        params: valid_params.merge(redirect_uri: redirect_uri),
        resource: @user,
      )

      assert_not result.success?, redirect_uri
      assert_equal "invalid_request", result.error
    end
  end

  test "fails without code_challenge" do
    result = authorize_service_call(
      params: valid_params.except(:code_challenge),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for non-S256 code_challenge_method" do
    result = authorize_service_call(
      params: valid_params.merge(code_challenge_method: "plain"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails when scope does not include openid" do
    result = authorize_service_call(
      params: valid_params.merge(scope: "profile email"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_equal "scope must include openid", result.error_description
  end

  test "fails for comma-delimited scope" do
    result = authorize_service_call(
      params: valid_params.merge(scope: "openid,email"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails when non-Palm client requests disallowed scopes" do
    %w(palm.read admin all write write:org).each do |scope|
      assert_no_difference "ClientAuthorizationCode.count" do
        result = authorize_service_call(
          params: valid_params.merge(scope: "openid #{scope}"),
          resource: @user,
        )

        assert_not result.success?, scope
        assert_equal "invalid_scope", result.error
      end
    end
  end

  test "palm iOS client can request palm.read" do
    client = OidcClientRegistry.find!("app-ios-rp")
    assert_difference "ClientAuthorizationCode.count", 1 do
      result = authorize_service_call(
        params: valid_params(
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          scope: "openid palm.read",
        ),
        resource: @user,
      )

      assert_predicate result, :success?
    end

    code = ClientAuthorizationCode.last

    assert_equal "openid palm.read", code.scope
    assert_equal client.client_id, code.client_id
  end

  test "palm Android client can request palm.read" do
    client = OidcClientRegistry.find!("app-android-rp")
    assert_difference "ClientAuthorizationCode.count", 1 do
      result = authorize_service_call(
        params: valid_params(
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          scope: "openid palm.read",
        ),
        resource: @user,
      )

      assert_predicate result, :success?
    end

    code = ClientAuthorizationCode.last

    assert_equal "openid palm.read", code.scope
    assert_equal client.client_id, code.client_id
  end

  test "state is included in redirect URL when provided" do
    result = authorize_service_call(
      params: valid_params.merge(state: "my_state_123"),
      resource: @user,
    )

    assert_predicate result, :success?
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_equal "my_state_123", query["state"]
  end

  test "fails when state is not provided" do
    result = authorize_service_call(
      params: valid_params.except(:state),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_equal "state is required", result.error_description
  end

  test "fails for inactive resource without issuing authorization code" do
    @user.update!(
      deactivated_at: Time.current,
      discarded_at: Time.current,
      purged_at: 1.day.from_now,
    )

    assert_no_difference "ClientAuthorizationCode.count" do
      result = authorize_service_call(
        params: valid_params,
        resource: @user,
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "resource is not active", result.error_description
    end
  end

  test "authorization code is stored in database" do
    assert_difference "ClientAuthorizationCode.count", 1 do
      authorize_service_call(
        params: valid_params,
        resource: @user,
      )
    end

    code = ClientAuthorizationCode.last

    assert_equal @user.id, code.user_id
    assert_equal "core-next-rp", code.client_id
    assert_equal @redirect_uri, code.redirect_uri
    assert_equal @code_challenge, code.code_challenge
    assert_equal "S256", code.code_challenge_method
  end

  # --- Operator OIDC tests ---

  test "issues authorization code for operator with org client" do
    staff = operators(:one)
    org_client = OidcClientRegistry.find("core-next-rp")
    org_redirect_uri = org_client.redirect_uris.first

    result = authorize_service_call(
      params: {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: org_redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        state: "staff_state",
        nonce: "staff_nonce",
        scope: "openid profile email",
      },
      resource: staff,
    )

    assert_predicate result, :success?
    assert_not_nil result.redirect_url
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_predicate query["code"], :present?
    assert_equal "staff_state", query["state"]
  end

  test "operator authorization code is stored with staff_id backing column" do
    staff = operators(:one)
    org_client = OidcClientRegistry.find("core-next-rp")
    org_redirect_uri = org_client.redirect_uris.first

    assert_difference "OperatorAuthorizationCode.count", 1 do
      authorize_service_call(
        params: {
          response_type: "code",
          client_id: "core-next-rp",
          redirect_uri: org_redirect_uri,
          code_challenge: @code_challenge,
          code_challenge_method: "S256",
          state: "staff_state",
          nonce: "staff_nonce",
          scope: "openid profile email",
        },
        resource: staff,
      )
    end

    code = OperatorAuthorizationCode.last

    assert_equal staff.id, code.staff_id
    assert_equal "core-next-rp", code.client_id
  end

  test "issues authorization code for visitor with com client" do
    visitor = create_visitor!
    com_client = OidcClientRegistry.find("core-next-rp")
    com_redirect_uri = com_client.redirect_uris.first

    result = authorize_service_call(
      params: {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: com_redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        state: "visitor_state",
        nonce: "visitor_nonce",
        scope: "openid profile email",
      },
      resource: visitor,
    )

    assert_predicate result, :success?
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_predicate query["code"], :present?
    assert_equal "visitor_state", query["state"]
  end

  test "visitor authorization code is stored with visitor_id" do
    visitor = create_visitor!
    com_client = OidcClientRegistry.find("core-next-rp")
    com_redirect_uri = com_client.redirect_uris.first

    assert_difference "VisitorAuthorizationCode.count", 1 do
      authorize_service_call(
        params: {
          response_type: "code",
          client_id: "core-next-rp",
          redirect_uri: com_redirect_uri,
          code_challenge: @code_challenge,
          code_challenge_method: "S256",
          state: "visitor_state",
          nonce: "visitor_nonce",
          scope: "openid profile email",
        },
        resource: visitor,
      )
    end

    code = VisitorAuthorizationCode.last

    assert_equal visitor.id, code.visitor_id
    assert_equal "core-next-rp", code.client_id
  end

  private

  def valid_params(overrides = {})
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      state: "test_state",
      nonce: "test_nonce",
      scope: "openid profile email",
    }.merge(overrides)
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    Visitor.create!
  end

  def authorize_service_call(params:, resource:, session_token: nil, **)
    session_token ||= default_session_token_for(resource)

    OidcAuthorizeCoordinator.call(
      params: params,
      resource: resource,
      session_token: session_token,
      **,
    )
  end

  def default_session_token_for(resource)
    case resource
    when Client
      @user_session_token ||= ClientToken.create!(user: @user)
    when Operator
      @staff_session_token ||= OperatorToken.create!(staff: resource)
    when Visitor
      ensure_visitor_reference_records!
      ensure_visitor_token_reference_records!
      @visitor_session_token ||= VisitorToken.create!(visitor: resource, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    else
      raise ArgumentError, "unsupported resource: #{resource.class.name}"
    end
  end
end
