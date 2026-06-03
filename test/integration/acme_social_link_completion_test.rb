# typed: false
# frozen_string_literal: true

require "test_helper"

# Controller-level behavior for the acme app social-link completion endpoint.
#
# The sign callback for a grant-backed app social link emits a one-shot signed
# result and posts it to acme completion. These tests pin that:
#   - acme consumes the result and performs the final link commit
#   - success redirects to the acme settings connections page
#   - the one-shot result cannot be replayed
#   - com/org sign surfaces expose no social link routes at all
class AcmeSocialLinkCompletionTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "acme completion commits the social link under acme authority and rejects replay" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "linkcompl_#{SecureRandom.hex(4)}")
    uid = "completion_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid, token: "completion_token")

    grant_session = seed_app_social_link_grant_session(provider: "google_app", user: user, ri: "jp")

    # The sign callback must only emit the acme completion form (evidence), not
    # commit the link inline.
    assert_no_difference("ClientGoogleIdentity.count") do
      get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers)
    end
    assert_response :ok
    assert_includes response.body, "social-completion-form"

    form = response.parsed_body.at_css("form#social-completion-form")
    action = form["action"]
    result_token = form.at_css("input[name='social_ceremony_result']")["value"]

    assert_predicate result_token, :present?, "completion form must carry the signed result token"

    # First completion: acme consumes the result and creates the identity.
    assert_difference("ClientGoogleIdentity.count", 1) do
      post action, params: { social_ceremony_result: result_token, ri: "jp" }, headers: { "Host" => @acme_host }
    end

    assert_redirected_to acme_app_settings_connections_url(ri: "jp", host: @acme_host)
    identity = ClientGoogleIdentity.find_by!(uid: uid)

    assert_equal user.id, identity.user_id
    assert_equal "completion_token", identity.token

    # Replay of the one-shot result must be rejected without a second commit.
    assert_no_difference("ClientGoogleIdentity.count") do
      post action, params: { social_ceremony_result: result_token, ri: "jp" }, headers: { "Host" => @acme_host }
    end

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp", host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end

  test "acme completion rejects a malformed social result without committing" do
    assert_no_difference("ClientGoogleIdentity.count") do
      post completion_acme_app_social_authentication_url(provider: "google_app", ri: "jp", host: @acme_host),
           params: { social_ceremony_result: "not-a-real-token", ri: "jp" },
           headers: { "Host" => @acme_host }
    end

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp", host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end

  test "sign com and org surfaces expose no social routes" do
    # The app surface owns the social link route helper...
    assert_respond_to self, :continue_sign_app_social_authentication_path

    # ...while com/org sign surfaces expose no social authentication route at all.
    %w(com org).each do |surface|
      assert_not respond_to?("continue_sign_#{surface}_social_authentication_path"),
                 "sign/#{surface} must not expose a social authentication route helper"
    end
  end

  private

  def setup_google_mock_auth(uid:, token: "google_token")
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: token,
        refresh_token: "refresh_#{token}",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end
end
