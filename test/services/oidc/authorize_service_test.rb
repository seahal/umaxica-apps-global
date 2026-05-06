# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::AuthorizeServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_app")
    @redirect_uri = @client.redirect_uris.first
  end

  test "issues authorization code and returns redirect URL" do
    result = Oidc::AuthorizeService.call(
      params: valid_params,
      resource: @user,
    )

    assert_predicate result, :success?
    assert_not_nil result.redirect_url
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_equal @redirect_uri.split("?").first, "#{uri.scheme}://#{uri.host}:#{uri.port}#{uri.path}"
    assert_predicate query["code"], :present?
    assert_equal "test_state", query["state"]
  end

  test "fails for missing response_type" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.except(:response_type),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for wrong response_type" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.merge(response_type: "token"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for unknown client_id" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.merge(client_id: "unknown"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "unauthorized_client", result.error
  end

  test "fails for unregistered redirect_uri" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.merge(redirect_uri: "https://evil.com/callback"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails without code_challenge" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.except(:code_challenge),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for non-S256 code_challenge_method" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.merge(code_challenge_method: "plain"),
      resource: @user,
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "state is included in redirect URL when provided" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.merge(state: "my_state_123"),
      resource: @user,
    )

    assert_predicate result, :success?
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_equal "my_state_123", query["state"]
  end

  test "state is omitted from redirect URL when not provided" do
    result = Oidc::AuthorizeService.call(
      params: valid_params.except(:state),
      resource: @user,
    )

    assert_predicate result, :success?
    uri = URI.parse(result.redirect_url)
    query = URI.decode_www_form(uri.query).to_h

    assert_nil query["state"]
  end

  test "authorization code is stored in database" do
    assert_difference "UserAuthorizationCode.count", 1 do
      Oidc::AuthorizeService.call(
        params: valid_params,
        resource: @user,
      )
    end

    code = UserAuthorizationCode.last

    assert_equal @user.id, code.user_id
    assert_equal "core_app", code.client_id
    assert_equal @redirect_uri, code.redirect_uri
    assert_equal @code_challenge, code.code_challenge
    assert_equal "S256", code.code_challenge_method
  end

  # --- Staff OIDC tests ---

  test "issues authorization code for staff with org client" do
    staff = staffs(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first

    result = Oidc::AuthorizeService.call(
      params: {
        response_type: "code",
        client_id: "core_org",
        redirect_uri: org_redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        state: "staff_state",
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

  test "staff authorization code is stored with staff_id" do
    staff = staffs(:one)
    org_client = Oidc::ClientRegistry.find("core_org")
    org_redirect_uri = org_client.redirect_uris.first

    assert_difference "StaffAuthorizationCode.count", 1 do
      Oidc::AuthorizeService.call(
        params: {
          response_type: "code",
          client_id: "core_org",
          redirect_uri: org_redirect_uri,
          code_challenge: @code_challenge,
          code_challenge_method: "S256",
        },
        resource: staff,
      )
    end

    code = StaffAuthorizationCode.last

    assert_equal staff.id, code.staff_id
    assert_equal "core_org", code.client_id
  end

  private

  def valid_params
    {
      response_type: "code",
      client_id: "core_app",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      state: "test_state",
    }
  end
end
