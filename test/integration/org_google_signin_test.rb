# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgGoogleSigninTest < ActionDispatch::IntegrationTest
  fixtures :operator_statuses, :operator_visibilities, :operator_google_identity_statuses,
           :operator_token_statuses, :operator_token_kinds, :operator_token_binding_methods,
           :operator_token_dbsc_statuses, :client_statuses, :client_google_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
  end

  teardown do
    OmniAuth.config.mock_auth[:google_org] = nil
  end

  test "linked active operator signs in with org token and org audit only" do
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "linked-org-google-uid",
      provider: "google_org",
      token: "old-token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: OperatorGoogleIdentityStatus::ACTIVE,
    )
    OmniAuth.config.mock_auth[:google_org] = google_auth(uid: "linked-org-google-uid", token: "new-token")

    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ENABLED" => "false") do
      state = start_org_google_signin

      assert_difference("OperatorToken.count", 1) do
        assert_difference("OperatorChronicle.count", 1) do
          assert_no_difference [
            "Client.count",
            "ClientGoogleIdentity.count",
            "ClientToken.count",
            "ClientChronicle.count",
          ] do
            get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
                params: { state: state },
                headers: social_callback_headers(@host)
          end
        end
      end
    end

    assert_response :redirect
    assert_equal "new-token", staff.reload.operator_google_identity.token
    token = OperatorToken.order(:id).last

    assert_equal staff.id, token.staff_id
    assert_nil token.try(:user_id)
    audit = OperatorChronicle.order(:id).last

    assert_equal "Operator", audit.subject_type
    assert_equal staff.id, audit.subject_id
    assert_equal "social", audit.context.fetch("auth_method")
    assert_equal "google", audit.context.fetch("provider")
  end

  test "unknown google uid is rejected without provisioning operator or identity" do
    OmniAuth.config.mock_auth[:google_org] = google_auth(uid: "unknown-org-google-uid")

    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ENABLED" => "false") do
      state = start_org_google_signin

      assert_no_difference [
        "Operator.count",
        "OperatorGoogleIdentity.count",
        "OperatorToken.count",
        "Client.count",
        "ClientGoogleIdentity.count",
        "ClientChronicle.count",
      ] do
        get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to new_sign_org_sign_in_url(ri: "jp")
  end

  test "inactive linked operator is rejected without issuing token" do
    staff = Operator.create!(status_id: OperatorStatus::NOTHING, visibility_id: OperatorVisibility::STAFF)
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "inactive-org-google-uid",
      provider: "google_org",
      token: "old-token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: OperatorGoogleIdentityStatus::ACTIVE,
    )
    OmniAuth.config.mock_auth[:google_org] = google_auth(uid: "inactive-org-google-uid")

    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ENABLED" => "false") do
      state = start_org_google_signin

      assert_no_difference ["OperatorToken.count", "ClientToken.count", "ClientChronicle.count"] do
        get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to new_sign_org_sign_in_url(ri: "jp")
  end

  test "temporary signup creates operator identity and org session without client records" do
    OmniAuth.config.mock_auth[:google_org] = google_auth(
      uid: "temporary-signup-uid",
      token: "signup-token",
      email: "Allowed@Example.Test",
    )

    with_env(
      "ORG_GOOGLE_SIGNUP_ENABLED" => "true",
      "ORG_GOOGLE_SIGNIN_ENABLED" => "false",
      "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test",
    ) do
      state = start_org_google_signup

      assert_difference("Operator.count", 1) do
        assert_difference("OperatorGoogleIdentity.count", 1) do
          assert_difference("OperatorToken.count", 1) do
            assert_difference("OperatorChronicle.count", 2) do
              assert_no_difference ["Client.count", "ClientGoogleIdentity.count", "ClientChronicle.count"] do
                get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
                    params: { state: state },
                    headers: social_callback_headers(@host)
              end
            end
          end
        end
      end
    end

    assert_response :redirect
    identity = OperatorGoogleIdentity.find_by!(uid: "temporary-signup-uid", provider: "google_org")

    assert_equal OperatorStatus::ACTIVE, identity.staff.status_id
    assert_equal "signup-token", identity.token
    assert_equal identity.staff_id, OperatorToken.order(:id).last.staff_id

    provisioning_marker = OperatorChronicle
      .where(event_id: OperatorChronicleEvent::LOGIN_SUCCESS)
      .order(:id)
      .last
    login_audit = OperatorChronicle
      .where(event_id: OperatorChronicleEvent::LOGGED_IN)
      .order(:id)
      .last

    assert_equal Sign::Social::OrgOperatorProvisioner::SOURCE, provisioning_marker.context.fetch("source")
    assert_equal true, provisioning_marker.context.fetch("temporary_gateway")
    assert_equal "google_org", provisioning_marker.context.fetch("provider")
    assert_equal "social", login_audit.context.fetch("auth_method")
    assert_equal "google", login_audit.context.fetch("provider")
    assert_not_equal provisioning_marker.id, login_audit.id
  end

  test "temporary signup rejects unknown uid when flag off or allowlist missing" do
    OmniAuth.config.mock_auth[:google_org] = google_auth(uid: "flag-off-signup-uid", email: "allowed@example.test")

    state = nil
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      state = start_org_google_signup
    end

    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "false", "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count"] do
        get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    OmniAuth.config.mock_auth[:google_org] =
      google_auth(uid: "missing-allowlist-signup-uid", email: "allowed@example.test")
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ALLOWLIST" => nil) do
      state = start_org_google_signup

      assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count"] do
        get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end
  end

  test "temporary signup rejects unallowlisted email" do
    OmniAuth.config.mock_auth[:google_org] =
      google_auth(uid: "unallowlisted-email-signup-uid", email: "blocked@example.test")

    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "true", "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      state = start_org_google_signup

      assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count", "OperatorToken.count"] do
        get sign_org_auth_callback_url(provider: "google_org", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end
  end

  test "temporary signup tag is grep trackable for cleanup" do
    output = `rg -n "TEMP\\(org-google-social-gateway\\): remove before production cleanup" app config test plans`.lines

    assert output.any? { |line| line.include?("app/services/sign/social/org_operator_provisioner.rb") }
    assert output.any? { |line| line.include?("app/controllers/sign/org/social/authentications_controller.rb") }
  end

  private

  def start_org_google_signin
    post(
      continue_sign_org_social_authentication_path(provider: "google_org", ri: "jp"),
      headers: browser_headers.merge(social_callback_headers(@host)),
    )

    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
    session[:social_auth_state].presence ||
      Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s).fetch("state")
  end

  def start_org_google_signup
    post(
      signup_sign_org_social_authentication_path(provider: "google_org", ri: "jp"),
      headers: browser_headers.merge(social_callback_headers(@host)),
    )

    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
    session[:social_auth_state].presence ||
      Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s).fetch("state")
  end

  def google_auth(uid:, token: "token", email: nil)
    OmniAuth::AuthHash.new(
      provider: "google_org",
      uid: uid,
      credentials: {
        token: token,
        refresh_token: "refresh-token",
        expires_at: 1.week.from_now.to_i,
      },
      info: {
        email: email || "#{uid}@example.test",
      },
    )
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
