# typed: false
# frozen_string_literal: true

require "test_helper"

# A back-channel logout names the session it wants ended by an sid the issuer
# chose, which may match the token's own public id, the device session that
# issued it, or the oidc_sid recorded on the token. All three have to resolve to
# the same token, because a lookup that misses leaves the session alive after the
# issuer believes it ended.
class SignOidcLogoutSessionLookupTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  # The concern declares an after_action when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this test is
  # deliberately outside of.
  class Harness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::SignOidcLogout

    attr_accessor :resource, :session_public_id

    def invoke(name, ...) = send(name, ...)

    def token_class = ClientToken

    def current_resource = resource

    def current_session_public_id = session_public_id
  end

  setup do
    @harness = Harness.new
    @client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
  end

  def create_token(**attributes)
    ClientToken.create!(
      user_id: @client.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      **attributes,
    )
  end

  test "the session is found by the token's own public id" do
    token = create_token

    assert_equal token, @harness.invoke(:oidc_current_session_token, token.public_id)
  end

  test "the session is found by the device session that issued it" do
    device_session = ClientDeviceSession.create!(user_id: @client.id, public_id: SecureRandom.alphanumeric(21))
    token = create_token(device_session_id: device_session.id)

    assert_equal token, @harness.invoke(:oidc_current_session_token_by_device_session, device_session.public_id)
    assert_equal token, @harness.invoke(:oidc_current_session_token, device_session.public_id)
  end

  test "a device session that names nothing resolves to no token" do
    assert_nil @harness.invoke(:oidc_current_session_token_by_device_session, SecureRandom.alphanumeric(21))
  end

  test "the session is found by the oidc sid recorded on the token" do
    token = create_token
    sid = token.reload.oidc_sid

    assert_predicate sid, :present?
    assert_equal token, @harness.invoke(:oidc_current_session_token_by_sid, sid)
    assert_equal token, @harness.invoke(:oidc_current_session_token, sid)
  end

  test "an sid that names nothing resolves to no token at all" do
    assert_nil @harness.invoke(:oidc_current_session_token, "no-such-sid")
  end

  test "a confirmation is only asked for when there is a session to end" do
    assert_not @harness.invoke(:sign_out_confirmation_request?)

    @harness.session_public_id = "session-1"

    assert @harness.invoke(:sign_out_confirmation_request?)

    @harness.session_public_id = nil
    @harness.resource = @client

    assert @harness.invoke(:sign_out_confirmation_request?)
  end

  test "a logout request time that is not a timestamp is read as absent" do
    assert_nil @harness.invoke(:parse_oidc_logout_request_time, "not-a-time")
    assert_nil @harness.invoke(:parse_oidc_logout_request_time, nil)
    assert_equal Time.zone.iso8601("2026-08-31T00:00:00Z"),
                 @harness.invoke(:parse_oidc_logout_request_time, "2026-08-31T00:00:00Z")
  end

  test "an unparsable configured host is compared verbatim rather than treated as a match" do
    assert @harness.invoke(:oidc_logout_host_matches?, "www.umaxica.app", "www.umaxica.app")
    assert_not @harness.invoke(:oidc_logout_host_matches?, "www.umaxica.app", "evil.example.com")
    assert @harness.invoke(:oidc_logout_host_matches?, "[oops", "[oops")
    assert_not @harness.invoke(:oidc_logout_host_matches?, "www.umaxica.app", "[oops")
  end
end
