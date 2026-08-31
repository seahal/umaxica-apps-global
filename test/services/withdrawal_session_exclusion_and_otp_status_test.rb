# typed: false
# frozen_string_literal: true

require "test_helper"

# Withdrawal revokes every session except the one performing it. The identifier
# it is handed may be a token public id or, for an OIDC-issued session, the sid
# the issuer chose -- and excluding the wrong one signs the person out mid-flow.
class WithdrawalSessionExclusionAndOtpStatusTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  setup do
    @client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @lifecycle = WithdrawalLifecycle.new(actor: @client)
  end

  def create_token
    ClientToken.create!(
      user_id: @client.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
    )
  end

  test "a token public id excludes only that token" do
    kept = create_token
    other = create_token

    remaining = @lifecycle.send(:exclude_session_identifier, ClientToken.where(user_id: @client.id), kept.public_id)

    assert_includes remaining, other
    assert_not_includes remaining, kept
  end

  test "an issuer-chosen sid excludes the token carrying it as well" do
    kept = create_token
    other = create_token
    sid = kept.reload.oidc_sid

    assert_predicate sid, :present?
    assert @lifecycle.send(:uuid_identifier?, sid), "the issuer sid is expected to be a UUID"

    remaining = @lifecycle.send(:exclude_session_identifier, ClientToken.where(user_id: @client.id), sid)

    assert_includes remaining, other
    assert_not_includes remaining, kept
  end

  test "an identifier that is not a UUID is never matched against the issuer sid" do
    assert_not @lifecycle.send(:uuid_identifier?, "not-a-uuid")
    assert_not @lifecycle.send(:uuid_identifier?, nil)
    assert @lifecycle.send(:uuid_identifier?, SecureRandom.uuid)
  end

  # The occurrence status ids are cached per class, so an unrecognised class has
  # to be refused by name rather than cached as nil and answered from cache after.
  test "an unsupported occurrence status class is refused by name" do
    error =
      assert_raises(KeyError) do
        SignInOtpResender.send(:status_id_for, ClientTokenStatus, :ACTIVE)
      end

    assert_match(/ClientTokenStatus/, error.message)
  end

  test "the two email occurrence statuses resolve to persisted rows" do
    assert_equal EmailOccurrenceStatus::ACTIVE, SignInOtpResender.email_issued_status_id
    assert_equal EmailOccurrenceStatus::NOTHING, SignInOtpResender.email_blocked_status_id
  end
end
