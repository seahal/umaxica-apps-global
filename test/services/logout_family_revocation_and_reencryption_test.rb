# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-out revokes the whole refresh-token family, so a stolen token cannot be
# rotated back into a session. A token with no family recorded still has to be
# revoked on its own -- otherwise the one case where family tracking is missing
# is the one case where sign-out does nothing.
class LogoutFamilyRevocationAndReencryptionTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  setup do
    @client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    @coordinator = PalmLogoutCoordinator.new(request: nil)
  end

  def create_token(family_id: nil)
    ClientToken.create!(
      user_id: @client.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      refresh_token_family_id: family_id,
    )
  end

  test "every token in the family is revoked together" do
    family = SecureRandom.uuid
    first = create_token(family_id: family)
    second = create_token(family_id: family)
    unrelated = create_token(family_id: SecureRandom.uuid)

    @coordinator.send(:revoke_refresh_token_family!, first)

    assert_operator first.reload.discarded_at, :<=, Time.current
    assert_operator second.reload.discarded_at, :<=, Time.current
    assert_operator unrelated.reload.discarded_at, :>, Time.current
  end

  test "a token with no family recorded is still revoked on its own" do
    token = create_token
    other = create_token

    @coordinator.send(:revoke_refresh_token_family!, token)

    assert_operator token.reload.discarded_at, :<=, Time.current
    assert_operator other.reload.discarded_at, :>, Time.current,
                    "a missing family must not widen the revocation to every token"
  end

  test "a failed logout answers a result carrying only the error" do
    result = @coordinator.send(:failure, "invalid_request", "logout challenge not found")

    assert_not result.success
    assert_equal "invalid_request", result.error
    assert_equal "logout challenge not found", result.error_description
    assert_nil result.logout_url
    assert_nil result.transaction
    assert_nil result.resource
  end
end
