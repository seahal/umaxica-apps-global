# typed: false
# frozen_string_literal: true

require "test_helper"

# Controller-level behavior for social-link completion compatibility.
#
# The Sign callback for app settings social link is the durable authority. These tests pin that:
#   - Sign performs the final link commit
#   - Sign does not emit an Acme completion form for link
#   - malformed Acme completion posts do not commit
#   - com/org sign surfaces expose no social link routes at all
class AcmeSocialLinkCompletionTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "log.umaxica.app")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "sign callback commits the social link without acme completion" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "linkcompl_#{SecureRandom.hex(4)}")
    uid = "completion_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid, token: "completion_token")

    grant_session = seed_app_social_link_grant_session(provider: "google", user: user, ri: "jp")

    assert_difference("ClientGoogleIdentity.count", 1) do
      get sign_app_social_google_callback_url(ri: "jp"),
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers)
    end

    assert_redirected_to sign_app_settings_path(ri: "jp")
    assert_not_includes response.body.to_s, "social-completion-form"
    identity = ClientGoogleIdentity.find_by!(uid: uid)

    assert_equal user.id, identity.user_id
    assert_equal "completion_token", identity.token
  end

  test "acme completion rejects a malformed social result without committing" do
    assert_no_difference("ClientGoogleIdentity.count") do
      assert_no_difference("ClientOidcAuthorizationTransaction.count") do
        post completion_acme_app_social_authentication_url(id: "google", ri: "jp", host: @acme_host),
             params: { social_ceremony_result: "not-a-real-token", ri: "jp" },
             headers: social_completion_browser_headers
      end
    end

    assert_response :unprocessable_content
    assert_nil response.location
    assert_includes response.body, I18n.t("sign.app.social.sessions.create.failure")
  end

  test "acme social login start delegates to sign with a login ceremony grant" do
    assert_no_difference("Client.count") do
      post continue_acme_app_social_authentication_url(id: "google", ri: "jp", host: @acme_host),
           headers: { "Host" => @acme_host }
    end

    assert_response :see_other

    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query)

    assert_equal ENV.fetch("ID_SERVICE_URL", "id.app.localhost"), location.host
    assert_equal "/social/google/sign/in", location.path
    assert_equal "sign_in", query["entry"]
    assert_equal "jp", query["ri"]
    assert_predicate query["social_ceremony_grant"], :present?

    grant = IdentitySocialCeremonyGrant.decode(
      query.fetch("social_ceremony_grant"),
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )

    assert_equal "login", grant["operation"]
    assert_equal "google", grant["provider"]
    assert_equal "anonymous", grant["actor_ref"]
  end

  test "sign com and org surfaces expose no social routes" do
    # The app surface owns the social login route helper...
    assert_respond_to self, :sign_app_social_google_sign_in_path

    # ...while com/org sign surfaces expose no social authentication route at all.
    %w(com org).each do |surface|
      assert_not respond_to?("continue_sign_#{surface}_social_authentication_path"),
                 "sign/#{surface} must not expose a social authentication route helper"
    end
  end

  private

  def social_completion_browser_headers
    {
      "Host" => @acme_host,
      "Origin" => "null",
      "Sec-Fetch-Site" => "same-site",
    }
  end

  def setup_google_mock_auth(uid:, token: "google_token")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
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
